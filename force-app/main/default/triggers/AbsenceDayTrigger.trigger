trigger AbsenceDayTrigger on flair__Absence_Day__c (after update, before delete) {
    AbsenceDayTriggerHandler handler = new AbsenceDayTriggerHandler();
    if (Trigger.isUpdate && Trigger.isAfter) {
        // handler.onAfterUpdate(Trigger.oldMap, Trigger.newMap);
    }
    if (Trigger.isDelete) {
        handler.onBeforeDelete(Trigger.old);
    }
}