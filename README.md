# Commission Manager - Salesforce 2GP Package

A Salesforce Second-Generation Package (2GP) for managing sales commissions with tiered logic, split commissions, clawbacks, and effective dating.

## Features

- **Tiered Commission Rates**: Configure multiple tiers with progressive rates (e.g., 5% up to $50K, 7% for $50K-$100K, 10% above $100K)
- **Split Commissions**: Automatically split commissions between Sales Reps, Sales Engineers, and Managers
- **Clawback Processing**: Automatic commission reversal when deals move from Closed Won to Closed Lost
- **Effective Dating**: Plans are date-bounded to support fiscal period changes
- **Real-time Estimator**: LWC component shows estimated commission on Opportunity pages

## Installation

### Prerequisites
- Salesforce CLI installed
- Dev Hub enabled org
- Namespace registered (default: `commapp`)

### Deploy to Scratch Org
```bash
# Create scratch org
sf org create scratch -f config/project-scratch-def.json -a CommTest

# Deploy source
sf project deploy start --target-org CommTest

# Assign permission set
sf org assign permset --name Commission_Admin --target-org CommTest
```

### Create Package
```bash
# Create package (first time only)
sf package create \
  --name "CommissionManager" \
  --package-type Managed \
  --path force-app \
  --target-dev-hub MyDevHub

# Create package version
sf package version create \
  --package "CommissionManager" \
  --definition-file config/project-scratch-def.json \
  --installation-key-bypass \
  --wait 20 \
  --code-coverage
```

## Data Model

### Commission_Plan__c
Master plan with effective dates defining when rules apply.

| Field | Type | Description |
|-------|------|-------------|
| Name | Text | Plan name (e.g., "Q3 2024 Sales Plan") |
| Effective_Start_Date__c | Date | Plan validity start |
| Effective_End_Date__c | Date | Plan validity end |
| Is_Active__c | Checkbox | Active flag |
| Description__c | Long Text | Plan description |

### Commission_Rule__c
Tiered rates and role-based splits (Master-Detail to Plan).

| Field | Type | Description |
|-------|------|-------------|
| Min_Amount__c | Currency | Tier floor |
| Max_Amount__c | Currency | Tier ceiling (null = unlimited) |
| Rate__c | Percent | Commission rate |
| Role__c | Picklist | Sales Rep / Sales Engineer / Manager |
| Split_Percentage__c | Percent | Split for this role |
| Order__c | Number | Evaluation order |

### Commission_Statement__c
Calculated commission records.

| Field | Type | Description |
|-------|------|-------------|
| Opportunity__c | Lookup | Source opportunity |
| Payee__c | Lookup(User) | Commission recipient |
| Amount__c | Currency | Commission amount |
| Status__c | Picklist | Pending / Approved / Paid / Clawback |
| Clawback_Reference__c | Lookup(Self) | Links to original if clawback |

## Usage

### Setting Up a Commission Plan

1. Create a Commission Plan record with effective dates
2. Create Commission Rules as child records:
   - Define tiers with Min/Max amounts
   - Set rates for each tier
   - Configure splits per role (Sales Rep: 60%, SE: 25%, Manager: 15%)
3. Mark the plan as Active

### Automatic Commission Calculation

When an Opportunity moves to "Closed Won":
1. System finds active plan matching the Close Date
2. Applies tiered rate logic to calculate base commission
3. Creates Commission Statements for each role based on splits
4. Statements start in "Pending" status

### Clawback Processing

When an Opportunity moves from "Closed Won" to "Closed Lost":
1. System finds existing statements within clawback period (default: 90 days)
2. Creates negative clawback statements
3. Marks original statements as "Clawback" status

## Configuration

### Custom Metadata Settings (Commission_Setting__mdt)

| Setting | Default | Description |
|---------|---------|-------------|
| Default_Clawback_Days__c | 90 | Days after which clawback doesn't apply |
| Enable_Split_Commissions__c | true | Enable multi-role splits |
| Calculation_Trigger_Stage__c | Closed Won | Stage that triggers calculation |

## Security

- All SOQL uses `WITH USER_MODE` for FLS enforcement
- All DML uses `Security.stripInaccessible()` for field security
- No SOQL/DML in loops
- No hardcoded IDs or credentials

## Permission Sets

- **Commission_Admin**: Full CRUD on all commission objects
- **Commission_User**: Read-only access for sales users

## Testing

Run all tests:
```bash
sf apex run test --target-org CommTest --code-coverage --result-format human
```

## Project Structure

```
commission-manager/
├── force-app/main/default/
│   ├── classes/
│   │   ├── CommissionCalculatorService.cls
│   │   ├── CommissionClawbackService.cls
│   │   ├── CommissionSelector.cls
│   │   ├── CommissionTriggerHandler.cls
│   │   └── *Test.cls
│   ├── triggers/
│   │   └── OpportunityTrigger.trigger
│   ├── lwc/
│   │   └── commissionEstimator/
│   ├── objects/
│   │   ├── Commission_Plan__c/
│   │   ├── Commission_Rule__c/
│   │   ├── Commission_Statement__c/
│   │   └── Commission_Setting__mdt/
│   ├── customMetadata/
│   │   └── Commission_Setting.Default.md-meta.xml
│   └── permissionsets/
├── config/
│   └── project-scratch-def.json
└── sfdx-project.json
```

## License

MIT License
