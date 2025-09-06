;; Title: Medicine Expiry Tracker and Warning System
;; Description: Track medicine inventory, expiry dates, and generate warning tokens
;; Version: 1.0.0

;; Constants for error codes
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_EXISTS (err u202))
(define-constant ERR_INVALID_PARAMETERS (err u203))
(define-constant ERR_EXPIRED_MEDICINE (err u204))
(define-constant ERR_INSUFFICIENT_QUANTITY (err u205))
(define-constant ERR_INVALID_DATE (err u206))
(define-constant ERR_INACTIVE_PHARMACIST (err u207))
(define-constant ERR_INVALID_STATUS (err u208))

;; Warning thresholds (in blocks)
(define-constant WARNING_30_DAYS u4320)  ;; ~30 days in blocks
(define-constant WARNING_60_DAYS u8640)  ;; ~60 days in blocks
(define-constant WARNING_90_DAYS u12960) ;; ~90 days in blocks

;; Data variables
(define-data-var next-medicine-id uint u1)
(define-data-var next-warning-id uint u1)
(define-data-var total-medicines uint u0)
(define-data-var total-active-medicines uint u0)
(define-data-var total-warnings uint u0)
(define-data-var total-expired-medicines uint u0)

;; Medicine records
(define-map medicines uint {
    medicine-id: uint,
    name: (string-ascii 100),
    manufacturer: (string-ascii 50),
    batch-number: (string-ascii 20),
    quantity: uint,
    unit-price: uint,
    manufacturing-date: uint,
    expiry-date: uint,
    pharmacist: principal,
    status: (string-ascii 20),
    created-at: uint,
    updated-at: uint
})

;; Pharmacist medicine mapping for quick lookups
(define-map pharmacist-medicines principal (list 100 uint))

;; Warning tokens for expiry alerts
(define-map warning-tokens uint {
    warning-id: uint,
    medicine-id: uint,
    pharmacist: principal,
    warning-type: (string-ascii 20),
    days-until-expiry: uint,
    created-at: uint,
    acknowledged: bool,
    acknowledged-at: (optional uint)
})

;; Batch tracking for duplicate prevention
(define-map batch-registry (string-ascii 20) uint)

;; Public functions

;; Add new medicine to inventory
(define-public (add-medicine (name (string-ascii 100))
                           (manufacturer (string-ascii 50))
                           (batch-number (string-ascii 20))
                           (quantity uint)
                           (unit-price uint)
                           (manufacturing-date uint)
                           (expiry-date uint))
    (let ((pharmacist tx-sender)
          (medicine-id (var-get next-medicine-id))
          (current-block stacks-block-height))
        
        ;; Validate input parameters
        (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len manufacturer) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len batch-number) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> quantity u0) ERR_INVALID_PARAMETERS)
        (asserts! (> unit-price u0) ERR_INVALID_PARAMETERS)
        
        ;; Validate dates
        (asserts! (< manufacturing-date expiry-date) ERR_INVALID_DATE)
        (asserts! (> expiry-date current-block) ERR_EXPIRED_MEDICINE)
        
        ;; Check if batch already exists
        (asserts! (is-none (map-get? batch-registry batch-number)) ERR_ALREADY_EXISTS)
        
        ;; Add medicine record
        (map-set medicines medicine-id {
            medicine-id: medicine-id,
            name: name,
            manufacturer: manufacturer,
            batch-number: batch-number,
            quantity: quantity,
            unit-price: unit-price,
            manufacturing-date: manufacturing-date,
            expiry-date: expiry-date,
            pharmacist: pharmacist,
            status: "active",
            created-at: current-block,
            updated-at: current-block
        })
        
        ;; Register batch
        (map-set batch-registry batch-number medicine-id)
        
        ;; Update pharmacist medicine list
        (update-pharmacist-medicine-list pharmacist medicine-id)
        
        ;; Update counters
        (var-set next-medicine-id (+ medicine-id u1))
        (var-set total-medicines (+ (var-get total-medicines) u1))
        (var-set total-active-medicines (+ (var-get total-active-medicines) u1))
        
        ;; Check if warning is needed
        (generate-warning-if-needed medicine-id)
        
        (ok medicine-id)))

;; Update medicine quantity
(define-public (update-medicine-quantity (medicine-id uint) (new-quantity uint))
    (let ((medicine-data (unwrap! (map-get? medicines medicine-id) ERR_NOT_FOUND))
          (pharmacist tx-sender))
        
        ;; Only the pharmacist who added the medicine can update it
        (asserts! (is-eq pharmacist (get pharmacist medicine-data)) ERR_UNAUTHORIZED)
        
        ;; Check if medicine is active
        (asserts! (is-eq (get status medicine-data) "active") ERR_INVALID_STATUS)
        
        ;; Update quantity
        (map-set medicines medicine-id 
            (merge medicine-data {
                quantity: new-quantity,
                updated-at: stacks-block-height
            }))
        
        ;; If quantity is 0, mark as depleted
        (if (is-eq new-quantity u0)
            (mark-medicine-depleted medicine-id)
            (ok true))))

;; Mark medicine as expired (automated or manual)
(define-public (mark-medicine-expired (medicine-id uint))
    (let ((medicine-data (unwrap! (map-get? medicines medicine-id) ERR_NOT_FOUND))
          (current-block stacks-block-height))
        
        ;; Check if caller is authorized (pharmacist or system)
        (asserts! (is-eq tx-sender (get pharmacist medicine-data)) ERR_UNAUTHORIZED)
        
        ;; Check if medicine is actually expired
        (asserts! (>= current-block (get expiry-date medicine-data)) ERR_INVALID_PARAMETERS)
        
        ;; Mark as expired
        (map-set medicines medicine-id 
            (merge medicine-data {
                status: "expired",
                updated-at: current-block
            }))
        
        ;; Update counters
        (var-set total-active-medicines (- (var-get total-active-medicines) u1))
        (var-set total-expired-medicines (+ (var-get total-expired-medicines) u1))
        
        (ok true)))

;; Generate warning tokens for medicines nearing expiry
(define-public (generate-expiry-warnings (days-threshold uint))
    (let ((current-block stacks-block-height)
          (threshold-blocks (blocks-from-days days-threshold))
          (pharmacist tx-sender))
        
        ;; Check threshold validity
        (asserts! (> days-threshold u0) ERR_INVALID_PARAMETERS)
        (asserts! (<= days-threshold u365) ERR_INVALID_PARAMETERS)
        
        ;; Generate warnings for pharmacist's medicines
        (generate-warnings-for-pharmacist pharmacist threshold-blocks)
        
        (ok true)))

;; Acknowledge warning token
(define-public (acknowledge-warning (warning-id uint))
    (let ((warning-data (unwrap! (map-get? warning-tokens warning-id) ERR_NOT_FOUND))
          (pharmacist tx-sender))
        
        ;; Only the pharmacist who received the warning can acknowledge it
        (asserts! (is-eq pharmacist (get pharmacist warning-data)) ERR_UNAUTHORIZED)
        
        ;; Check if warning is not already acknowledged
        (asserts! (is-eq (get acknowledged warning-data) false) ERR_INVALID_STATUS)
        
        ;; Acknowledge warning
        (map-set warning-tokens warning-id 
            (merge warning-data {
                acknowledged: true,
                acknowledged-at: (some stacks-block-height)
            }))
        
        (ok true)))

;; Remove medicine from inventory (for disposal or sale)
(define-public (remove-medicine (medicine-id uint))
    (let ((medicine-data (unwrap! (map-get? medicines medicine-id) ERR_NOT_FOUND))
          (pharmacist tx-sender))
        
        ;; Only the pharmacist who added the medicine can remove it
        (asserts! (is-eq pharmacist (get pharmacist medicine-data)) ERR_UNAUTHORIZED)
        
        ;; Mark as removed
        (map-set medicines medicine-id 
            (merge medicine-data {
                status: "removed",
                updated-at: stacks-block-height
            }))
        
        ;; Update counters if it was active
        (if (is-eq (get status medicine-data) "active")
            (var-set total-active-medicines (- (var-get total-active-medicines) u1))
            true)
        
        (ok true)))

;; Private functions

;; Mark medicine as depleted
(define-private (mark-medicine-depleted (medicine-id uint))
    (let ((medicine-data (unwrap! (map-get? medicines medicine-id) ERR_NOT_FOUND)))
        (map-set medicines medicine-id 
            (merge medicine-data {
                status: "depleted",
                updated-at: stacks-block-height
            }))
        (var-set total-active-medicines (- (var-get total-active-medicines) u1))
        (ok true)))

;; Update pharmacist medicine list
(define-private (update-pharmacist-medicine-list (pharmacist principal) (medicine-id uint))
    (let ((current-list (default-to (list) (map-get? pharmacist-medicines pharmacist))))
        (match (as-max-len? (append current-list medicine-id) u100)
            updated-list (begin
                (map-set pharmacist-medicines pharmacist updated-list)
                true)
            true)))

;; Generate warning if needed for a medicine
(define-private (generate-warning-if-needed (medicine-id uint))
    (match (map-get? medicines medicine-id)
        medicine-data
        (let ((current-block stacks-block-height)
              (expiry-date (get expiry-date medicine-data))
              (blocks-until-expiry (- expiry-date current-block)))
            
            ;; Check if warning is needed (within 90 days)
            (if (<= blocks-until-expiry WARNING_90_DAYS)
                (begin
                    (create-warning-token medicine-id blocks-until-expiry)
                    true)
                true))
        true))

;; Create a warning token
(define-private (create-warning-token (medicine-id uint) (blocks-until-expiry uint))
    (let ((warning-id (var-get next-warning-id)))
        (match (map-get? medicines medicine-id)
            medicine-data
            (let ((warning-type (get-warning-type blocks-until-expiry))
                  (days-until-expiry (/ blocks-until-expiry u144))) ;; ~144 blocks per day
                
                (map-set warning-tokens warning-id {
                    warning-id: warning-id,
                    medicine-id: medicine-id,
                    pharmacist: (get pharmacist medicine-data),
                    warning-type: warning-type,
                    days-until-expiry: days-until-expiry,
                    created-at: stacks-block-height,
                    acknowledged: false,
                    acknowledged-at: none
                })
                
                (var-set next-warning-id (+ warning-id u1))
                (var-set total-warnings (+ (var-get total-warnings) u1))
                
                true)
            true)))

;; Get warning type based on blocks until expiry
(define-private (get-warning-type (blocks-until-expiry uint))
    (if (<= blocks-until-expiry WARNING_30_DAYS)
        "critical"
        (if (<= blocks-until-expiry WARNING_60_DAYS)
            "warning"
            "info")))

;; Generate warnings for a specific pharmacist
(define-private (generate-warnings-for-pharmacist (pharmacist principal) (threshold-blocks uint))
    (let ((medicine-list (default-to (list) (map-get? pharmacist-medicines pharmacist))))
        ;; This would iterate through medicines and create warnings
        ;; Implementation simplified for demo purposes
        true))

;; Convert days to blocks (approximate)
(define-private (blocks-from-days (days uint))
    (* days u144)) ;; ~144 blocks per day

;; Read-only functions

;; Get medicine by ID
(define-read-only (get-medicine (medicine-id uint))
    (map-get? medicines medicine-id))

;; Get warning token by ID
(define-read-only (get-warning-token (warning-id uint))
    (map-get? warning-tokens warning-id))

;; Get medicines by pharmacist
(define-read-only (get-pharmacist-medicines (pharmacist principal))
    (map-get? pharmacist-medicines pharmacist))

;; Get medicine by batch number
(define-read-only (get-medicine-by-batch (batch-number (string-ascii 20)))
    (match (map-get? batch-registry batch-number)
        medicine-id (map-get? medicines medicine-id)
        none))

;; Get system statistics
(define-read-only (get-system-stats)
    {
        total-medicines: (var-get total-medicines),
        active-medicines: (var-get total-active-medicines),
        expired-medicines: (var-get total-expired-medicines),
        total-warnings: (var-get total-warnings),
        next-medicine-id: (var-get next-medicine-id),
        next-warning-id: (var-get next-warning-id)
    })

;; Check if medicine is expired
(define-read-only (is-medicine-expired (medicine-id uint))
    (match (map-get? medicines medicine-id)
        medicine-data (>= stacks-block-height (get expiry-date medicine-data))
        false))

;; Get medicines expiring within specified days
(define-read-only (get-expiring-medicines (days uint))
    (let ((threshold-blocks (blocks-from-days days))
          (current-block stacks-block-height))
        ;; This would return a filtered list of medicines
        ;; Implementation simplified for demo purposes
        { threshold: threshold-blocks, current-block: current-block }))

;; Check medicine status
(define-read-only (check-medicine-status (medicine-id uint))
    (match (map-get? medicines medicine-id)
        medicine-data {
            exists: true,
            status: (get status medicine-data),
            expired: (>= stacks-block-height (get expiry-date medicine-data)),
            quantity: (get quantity medicine-data),
            days-until-expiry: (/ (- (get expiry-date medicine-data) stacks-block-height) u144)
        }
        {
            exists: false,
            status: "",
            expired: false,
            quantity: u0,
            days-until-expiry: u0
        }))
