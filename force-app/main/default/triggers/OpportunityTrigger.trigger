/**
 * @description Trigger on Opportunity for commission calculations
 */
trigger OpportunityTrigger on Opportunity (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        CommissionTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
