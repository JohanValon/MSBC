trigger AbsenceTrigger on flair__Absence__c (before delete, after update) {
    AbsenceTriggerHandler handler = new AbsenceTriggerHandler();
    if (Trigger.isDelete) {
        handler.onBeforeDelete(Trigger.oldMap);
    } else if (Trigger.isUpdate && Trigger.isAfter) {
        handler.onAfterUpdate(Trigger.oldMap, Trigger.newMap);
    }
}