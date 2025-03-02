trigger AbsenceTrigger on flair__Absence__c (before delete, before update, after update) {
    static final String EXECUTOR = 'AbsenceTriggerHandler';
     if (Trigger.isUpdate &&  Trigger.isBefore) {
        ChainManager.instance.registerExecutor(EXECUTOR);
        AbsenceTriggerHandler.onBeforeUpdate(Trigger.oldMap, Trigger.newMap);
    } else if (Trigger.isUpdate && Trigger.isAfter) {
        AbsenceTriggerHandler.onAfterUpdate(Trigger.oldMap, Trigger.newMap);
        ChainManager.instance.startChain(EXECUTOR);
    } else if (Trigger.isDelete) {
        AbsenceTriggerHandler.onBeforeDelete(Trigger.oldMap);
    }
}