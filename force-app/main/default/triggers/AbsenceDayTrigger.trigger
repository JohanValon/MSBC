trigger AbsenceDayTrigger on flair__Absence_Day__c (before update, after update, before delete) {
    static final String EXECUTOR = 'AbsenceDayTriggerHandler';
    if (Trigger.isUpdate && Trigger.isBefore) {
        ChainManager.instance.registerExecutor(EXECUTOR);
        AbsenceDayTriggerHandler.onBeforeUpdate(Trigger.oldMap, Trigger.newMap);
    }else if (Trigger.isUpdate && Trigger.isAfter) {
        AbsenceDayTriggerHandler.onAfterUpdate(Trigger.oldMap, Trigger.newMap);
        ChainManager.instance.startChain(EXECUTOR);
    } if (Trigger.isDelete) {
        AbsenceDayTriggerHandler.onBeforeDelete(Trigger.old);
    }
}