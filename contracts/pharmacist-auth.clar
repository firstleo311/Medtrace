;; Title: Pharmacist Authentication System
;; Description: Secure authentication and registration system for pharmacists
;; Version: 1.0.0

;; Constants for error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_LICENSE (err u103))
(define-constant ERR_INVALID_PARAMETERS (err u104))
(define-constant ERR_INACTIVE_PHARMACIST (err u105))
(define-constant ERR_INVALID_STATUS (err u106))

;; Contract owner/admin
(define-constant CONTRACT_OWNER tx-sender)

;; Data variables
(define-data-var next-pharmacist-id uint u1)
(define-data-var total-pharmacists uint u0)
(define-data-var total-active-pharmacists uint u0)

;; Data structures
(define-map pharmacists principal {
    pharmacist-id: uint,
    name: (string-ascii 50),
    license-number: (string-ascii 20),
    pharmacy-name: (string-ascii 100),
    registration-date: uint,
    status: (string-ascii 20),
    total-medicines: uint,
    last-activity: uint
})

;; License number mapping for uniqueness
(define-map license-registry (string-ascii 20) principal)

;; Activity log for audit trail
(define-map activity-log uint {
    pharmacist: principal,
    action: (string-ascii 50),
    timestamp: uint,
    details: (string-ascii 200)
})

(define-data-var next-activity-id uint u1)

;; Public functions

;; Register a new pharmacist
(define-public (register-pharmacist (name (string-ascii 50)) 
                                  (license-number (string-ascii 20)) 
                                  (pharmacy-name (string-ascii 100)))
    (let ((pharmacist tx-sender)
          (current-id (var-get next-pharmacist-id)))
        ;; Validate input parameters
        (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len license-number) u5) ERR_INVALID_LICENSE)
        (asserts! (> (len pharmacy-name) u0) ERR_INVALID_PARAMETERS)
        
        ;; Check if pharmacist already exists
        (asserts! (is-none (map-get? pharmacists pharmacist)) ERR_ALREADY_EXISTS)
        
        ;; Check if license number already exists
        (asserts! (is-none (map-get? license-registry license-number)) ERR_ALREADY_EXISTS)
        
        ;; Register pharmacist
        (map-set pharmacists pharmacist {
            pharmacist-id: current-id,
            name: name,
            license-number: license-number,
            pharmacy-name: pharmacy-name,
            registration-date: stacks-block-height,
            status: "active",
            total-medicines: u0,
            last-activity: stacks-block-height
        })
        
        ;; Register license number
        (map-set license-registry license-number pharmacist)
        
        ;; Log activity
        (log-activity pharmacist "pharmacist_registered" 
                     (concat "Registered: " name))
        
        ;; Update counters
        (var-set next-pharmacist-id (+ current-id u1))
        (var-set total-pharmacists (+ (var-get total-pharmacists) u1))
        (var-set total-active-pharmacists (+ (var-get total-active-pharmacists) u1))
        
        (ok current-id)))

;; Update pharmacist profile
(define-public (update-pharmacist-profile (name (string-ascii 50)) 
                                        (pharmacy-name (string-ascii 100)))
    (let ((pharmacist tx-sender)
          (existing-data (unwrap! (map-get? pharmacists pharmacist) ERR_NOT_FOUND)))
        
        ;; Validate input
        (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len pharmacy-name) u0) ERR_INVALID_PARAMETERS)
        
        ;; Check if pharmacist is active
        (asserts! (is-eq (get status existing-data) "active") ERR_INACTIVE_PHARMACIST)
        
        ;; Update profile
        (map-set pharmacists pharmacist 
            (merge existing-data {
                name: name,
                pharmacy-name: pharmacy-name,
                last-activity: stacks-block-height
            }))
        
        ;; Log activity
        (log-activity pharmacist "profile_updated" 
                     (concat "Updated profile: " name))
        
        (ok true)))

;; Deactivate pharmacist (admin only)
(define-public (deactivate-pharmacist (pharmacist-address principal))
    (let ((existing-data (unwrap! (map-get? pharmacists pharmacist-address) ERR_NOT_FOUND)))
        
        ;; Only admin can deactivate
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        
        ;; Check if pharmacist is currently active
        (asserts! (is-eq (get status existing-data) "active") ERR_INVALID_STATUS)
        
        ;; Deactivate pharmacist
        (map-set pharmacists pharmacist-address 
            (merge existing-data {
                status: "inactive",
                last-activity: stacks-block-height
            }))
        
        ;; Update counter
        (var-set total-active-pharmacists (- (var-get total-active-pharmacists) u1))
        
        ;; Log activity
        (log-activity pharmacist-address "pharmacist_deactivated" 
                     "Pharmacist deactivated by admin")
        
        (ok true)))

;; Update medicine count for pharmacist (called by medicine-tracker contract)
(define-public (update-medicine-count (pharmacist-address principal) (new-count uint))
    (let ((existing-data (unwrap! (map-get? pharmacists pharmacist-address) ERR_NOT_FOUND)))
        
        ;; Update medicine count
        (map-set pharmacists pharmacist-address 
            (merge existing-data {
                total-medicines: new-count,
                last-activity: stacks-block-height
            }))
        
        (ok true)))

;; Private functions

;; Log activity for audit trail
(define-private (log-activity (pharmacist principal) (action (string-ascii 50)) (details (string-ascii 200)))
    (let ((activity-id (var-get next-activity-id)))
        (map-set activity-log activity-id {
            pharmacist: pharmacist,
            action: action,
            timestamp: stacks-block-height,
            details: details
        })
        (var-set next-activity-id (+ activity-id u1))
        activity-id))

;; Read-only functions

;; Get pharmacist profile
(define-read-only (get-pharmacist (pharmacist-address principal))
    (map-get? pharmacists pharmacist-address))

;; Check if pharmacist is active
(define-read-only (is-active-pharmacist (pharmacist-address principal))
    (match (map-get? pharmacists pharmacist-address)
        profile (is-eq (get status profile) "active")
        false))

;; Get pharmacist by license number
(define-read-only (get-pharmacist-by-license (license-number (string-ascii 20)))
    (match (map-get? license-registry license-number)
        pharmacist-address (map-get? pharmacists pharmacist-address)
        none))

;; Get activity log entry
(define-read-only (get-activity-log (activity-id uint))
    (map-get? activity-log activity-id))

;; Get system statistics
(define-read-only (get-system-stats)
    {
        total-pharmacists: (var-get total-pharmacists),
        active-pharmacists: (var-get total-active-pharmacists),
        next-pharmacist-id: (var-get next-pharmacist-id),
        next-activity-id: (var-get next-activity-id)
    })

;; Verify pharmacist credentials
(define-read-only (verify-pharmacist (pharmacist-address principal))
    (match (map-get? pharmacists pharmacist-address)
        profile {
            exists: true,
            active: (is-eq (get status profile) "active"),
            pharmacist-id: (get pharmacist-id profile),
            name: (get name profile),
            license: (get license-number profile)
        }
        {
            exists: false,
            active: false,
            pharmacist-id: u0,
            name: "",
            license: ""
        }))
