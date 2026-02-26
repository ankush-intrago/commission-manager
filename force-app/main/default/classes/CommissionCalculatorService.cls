/**
 * @description Core commission calculation engine. Handles tiered rate calculations,
 *              split commissions, and statement generation.
 */
public with sharing class CommissionCalculatorService {

    /**
     * @description Calculate commissions for a list of closed won opportunities
     * @param opportunities List of opportunities to calculate commissions for
     * @return List of Commission Statement records to be inserted
     */
    public static List<Commission_Statement__c> calculateCommissions(List<Opportunity> opportunities) {
        List<Commission_Statement__c> statements = new List<Commission_Statement__c>();

        if (opportunities == null || opportunities.isEmpty()) {
            return statements;
        }

        Commission_Setting__mdt settings = CommissionSelector.getDefaultSettings();
        Boolean enableSplits = settings != null ? settings.Enable_Split_Commissions__c : true;

        for (Opportunity opp : opportunities) {
            List<Commission_Plan__c> plans = CommissionSelector.getActivePlanForDate(opp.CloseDate);

            if (plans.isEmpty()) {
                continue;
            }

            Commission_Plan__c activePlan = plans[0];
            List<Commission_Statement__c> oppStatements = calculateForOpportunity(
                opp, activePlan, enableSplits
            );
            statements.addAll(oppStatements);
        }

        return statements;
    }

    /**
     * @description Calculate commission for a single opportunity
     * @param opp The opportunity
     * @param plan The active commission plan
     * @param enableSplits Whether to enable split commissions
     * @return List of Commission Statement records
     */
    @TestVisible
    private static List<Commission_Statement__c> calculateForOpportunity(
        Opportunity opp,
        Commission_Plan__c plan,
        Boolean enableSplits
    ) {
        List<Commission_Statement__c> statements = new List<Commission_Statement__c>();
        Decimal dealAmount = opp.Amount != null ? opp.Amount : 0;

        if (dealAmount <= 0) {
            return statements;
        }

        Map<String, List<Commission_Rule__c>> rulesByRole = groupRulesByRole(plan.Commission_Rules__r);

        if (enableSplits) {
            for (String role : rulesByRole.keySet()) {
                List<Commission_Rule__c> roleRules = rulesByRole.get(role);
                Commission_Statement__c statement = createStatementForRole(
                    opp, plan, roleRules, role, dealAmount
                );
                if (statement != null) {
                    statements.add(statement);
                }
            }
        } else {
            List<Commission_Rule__c> salesRepRules = rulesByRole.get('Sales Rep');
            if (salesRepRules != null && !salesRepRules.isEmpty()) {
                Commission_Statement__c statement = createStatementForRole(
                    opp, plan, salesRepRules, 'Sales Rep', dealAmount
                );
                if (statement != null) {
                    statements.add(statement);
                }
            }
        }

        return statements;
    }

    /**
     * @description Create a commission statement for a specific role
     * @param opp The opportunity
     * @param plan The commission plan
     * @param rules The rules for this role
     * @param role The role name
     * @param dealAmount The deal amount
     * @return Commission Statement record
     */
    private static Commission_Statement__c createStatementForRole(
        Opportunity opp,
        Commission_Plan__c plan,
        List<Commission_Rule__c> rules,
        String role,
        Decimal dealAmount
    ) {
        CommissionResult result = applyTieredRate(dealAmount, rules);

        if (result.commissionAmount <= 0) {
            return null;
        }

        Commission_Statement__c statement = new Commission_Statement__c();
        statement.Opportunity__c = opp.Id;
        statement.Commission_Plan__c = plan.Id;
        statement.Payee__c = opp.OwnerId;
        statement.Amount__c = result.commissionAmount;
        statement.Rate_Applied__c = result.effectiveRate;
        statement.Status__c = 'Pending';
        statement.Deal_Amount__c = dealAmount;
        statement.Calculation_Date__c = Datetime.now();
        statement.Role__c = role;

        return statement;
    }

    /**
     * @description Group commission rules by role
     * @param rules List of commission rules
     * @return Map of role to rules
     */
    private static Map<String, List<Commission_Rule__c>> groupRulesByRole(
        List<Commission_Rule__c> rules
    ) {
        Map<String, List<Commission_Rule__c>> rulesByRole = new Map<String, List<Commission_Rule__c>>();

        for (Commission_Rule__c rule : rules) {
            if (!rulesByRole.containsKey(rule.Role__c)) {
                rulesByRole.put(rule.Role__c, new List<Commission_Rule__c>());
            }
            rulesByRole.get(rule.Role__c).add(rule);
        }

        return rulesByRole;
    }

    /**
     * @description Apply tiered commission rate to deal amount
     * @param amount The deal amount
     * @param rules The tiered commission rules sorted by order
     * @return CommissionResult containing commission amount and effective rate
     */
    @TestVisible
    private static CommissionResult applyTieredRate(Decimal amount, List<Commission_Rule__c> rules) {
        Decimal totalCommission = 0;
        Decimal lastAppliedRate = 0;

        for (Commission_Rule__c rule : rules) {
            Decimal minAmount = rule.Min_Amount__c != null ? rule.Min_Amount__c : 0;
            Decimal maxAmount = rule.Max_Amount__c;
            Decimal rate = rule.Rate__c != null ? rule.Rate__c / 100 : 0;
            Decimal splitPct = rule.Split_Percentage__c != null ? rule.Split_Percentage__c / 100 : 1;

            if (amount < minAmount) {
                continue;
            }

            Decimal tierAmount;
            if (maxAmount == null || amount <= maxAmount) {
                tierAmount = amount - minAmount;
            } else {
                tierAmount = maxAmount - minAmount;
            }

            if (tierAmount > 0) {
                totalCommission += tierAmount * rate * splitPct;
                lastAppliedRate = rate * 100;
            }

            if (maxAmount != null && amount <= maxAmount) {
                break;
            }
        }

        return new CommissionResult(totalCommission, lastAppliedRate);
    }

    /**
     * @description Get estimated commission for an amount (used by LWC)
     * @param amount The deal amount to estimate
     * @return Estimated commission amount
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getEstimate(Decimal amount) {
        if (amount == null || amount <= 0) {
            return 0;
        }

        List<Commission_Plan__c> plans = CommissionSelector.getActivePlanForDate(Date.today());

        if (plans.isEmpty()) {
            return 0;
        }

        Commission_Plan__c plan = plans[0];
        List<Commission_Rule__c> salesRepRules = new List<Commission_Rule__c>();

        for (Commission_Rule__c rule : plan.Commission_Rules__r) {
            if (rule.Role__c == 'Sales Rep') {
                salesRepRules.add(rule);
            }
        }

        if (salesRepRules.isEmpty()) {
            return 0;
        }

        CommissionResult result = applyTieredRate(amount, salesRepRules);
        return result.commissionAmount;
    }

    /**
     * @description Inner class to hold commission calculation results
     */
    @TestVisible
    private class CommissionResult {
        public Decimal commissionAmount { get; private set; }
        public Decimal effectiveRate { get; private set; }

        public CommissionResult(Decimal commissionAmount, Decimal effectiveRate) {
            this.commissionAmount = commissionAmount;
            this.effectiveRate = effectiveRate;
        }
    }
}
