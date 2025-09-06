# 🏥 Medtrace - Medicine Expiry Token Warning System

[![Stacks](https://img.shields.io/badge/Built%20on-Stacks-5546FF?style=flat-square&logo=stacks)](https://stacks.co/)
[![Clarity](https://img.shields.io/badge/Smart%20Contracts-Clarity-8B5CF6?style=flat-square)](https://clarity-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](https://opensource.org/licenses/MIT)

## 🎯 Overview

**Medtrace** is a comprehensive blockchain-based medicine expiry tracking system designed for pharmacists and healthcare providers. The system leverages smart contracts on the Stacks blockchain to provide transparent, tamper-proof logging of medicine inventory, expiry dates, and automated warning systems.

## ✨ Key Features

### 💊 **Medicine Inventory Management**
- **Add New Medicines**: Register medicine batches with complete details
- **Track Expiry Dates**: Automated monitoring of expiration timelines  
- **Batch Management**: Handle multiple batches of the same medicine
- **Real-time Status Updates**: Live inventory status tracking

### 👨‍⚕️ **Pharmacist Authentication System**
- **Secure Registration**: Pharmacist credential verification
- **License Validation**: Professional license number tracking
- **Role-Based Access**: Different permission levels for staff
- **Activity Logging**: Complete audit trail of all actions

### ⚠️ **Automated Warning System**
- **Expiry Alerts**: Configurable warning periods (30, 60, 90 days)
- **Token-Based Notifications**: Blockchain-native alert mechanism
- **Priority Levels**: Critical, warning, and info notifications
- **Historical Tracking**: Complete warning history

### 🔒 **Security & Compliance**
- **Immutable Records**: Tamper-proof medicine tracking
- **Regulatory Compliance**: Audit-ready transaction logs
- **Data Integrity**: Cryptographic verification of all entries
- **Privacy Protection**: Secure handling of sensitive medical data

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Medtrace System                      │
├─────────────────────────────────────────────────────────┤
│  📊 Frontend Interface                                  │
│  ├── Pharmacist Dashboard                               │
│  ├── Medicine Inventory View                            │
│  └── Warning Alert Panel                                │
├─────────────────────────────────────────────────────────┤
│  🔗 Smart Contracts (Clarity)                          │
│  ├── medicine-tracker.clar (Inventory Management)       │
│  └── pharmacist-auth.clar (Authentication System)       │
├─────────────────────────────────────────────────────────┤
│  ⛓️  Stacks Blockchain                                  │
│  ├── Immutable Medicine Records                         │
│  ├── Pharmacist Authentication                          │
│  └── Warning Token System                               │
└─────────────────────────────────────────────────────────┘
```

## 🔧 Smart Contract Components

### **1. Medicine Tracker Contract**
- Medicine registration and inventory management
- Expiry date monitoring and validation
- Batch tracking and status updates
- Warning token generation and management

### **2. Pharmacist Authentication Contract** 
- Secure pharmacist registration system
- License verification and validation
- Role-based permission management
- Activity logging and audit trails

## 📊 Data Structures

### **Medicine Record**
```clarity
{
  medicine-id: uint,
  name: string-ascii 100,
  manufacturer: string-ascii 50,
  batch-number: string-ascii 20,
  quantity: uint,
  unit-price: uint,
  manufacturing-date: uint,
  expiry-date: uint,
  pharmacist: principal,
  status: string-ascii 20
}
```

### **Pharmacist Profile**
```clarity
{
  pharmacist-id: principal,
  name: string-ascii 50,
  license-number: string-ascii 20,
  pharmacy-name: string-ascii 100,
  registration-date: uint,
  status: string-ascii 20,
  total-medicines: uint
}
```

### **Warning Token**
```clarity
{
  warning-id: uint,
  medicine-id: uint,
  pharmacist: principal,
  warning-type: string-ascii 20,
  days-until-expiry: uint,
  created-at: uint,
  acknowledged: bool
}
```

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) v16 or higher
- [Stacks Wallet](https://www.hiro.so/wallet) for blockchain interaction

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/firstleo311/Medtrace.git
   cd Medtrace
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Run tests**
   ```bash
   npm test
   ```

4. **Check contract syntax**
   ```bash
   clarinet check
   ```

## 🧪 Usage Examples

### **Register a New Pharmacist**
```clarity
(register-pharmacist 
  "Dr. Sarah Johnson" 
  "PH12345678" 
  "HealthCare Pharmacy")
```

### **Add Medicine to Inventory**
```clarity
(add-medicine 
  "Amoxicillin 500mg" 
  "PharmaCorp" 
  "AMX2024001" 
  u100 
  u1500 
  u1704067200 ; Manufacturing date
  u1735603200  ; Expiry date
)
```

### **Generate Warning Tokens**
```clarity
(generate-expiry-warnings u30) ; Check medicines expiring in 30 days
```

### **Acknowledge Warnings**
```clarity
(acknowledge-warning u1) ; Acknowledge warning with ID 1
```

## 🔄 Workflow

1. **Pharmacist Registration** → Verify credentials and create profile
2. **Medicine Addition** → Register new medicine batches with expiry dates
3. **Automatic Monitoring** → System continuously checks expiry dates
4. **Warning Generation** → Create warning tokens for upcoming expiries
5. **Alert Management** → Pharmacists receive and acknowledge warnings
6. **Compliance Tracking** → Maintain audit logs for regulatory purposes

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Run all tests
npm test

# Check contract syntax
clarinet check

# Generate code coverage report
npm run coverage
```

## 📈 Benefits

### **For Pharmacists**
- ✅ Reduced medicine waste through timely expiry alerts
- ✅ Regulatory compliance with automated audit trails
- ✅ Improved inventory management and cost control
- ✅ Professional credential verification system

### **For Healthcare System**
- ✅ Enhanced patient safety through expiry prevention
- ✅ Transparent supply chain management
- ✅ Reduced healthcare costs from expired medicines
- ✅ Standardized tracking across multiple pharmacies

### **For Regulators**
- ✅ Immutable audit trails for compliance monitoring
- ✅ Real-time visibility into medicine distribution
- ✅ Automated reporting and compliance verification
- ✅ Enhanced oversight of pharmaceutical supply chain

## 🤝 Contributing

We welcome contributions from the healthcare and blockchain communities! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For questions, issues, or feature requests:
- 📧 Email: support@medtrace.healthcare
- 💬 Discord: [Medtrace Community](https://discord.gg/medtrace)
- 🐛 Issues: [GitHub Issues](https://github.com/firstleo311/Medtrace/issues)

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet/)

---

**Built with ❤️ for healthcare transparency and patient safety**
