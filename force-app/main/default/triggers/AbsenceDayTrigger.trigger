trigger AbsenceDayTrigger on flair__Absence_Day__c (after update) {
    AbsenceDayTriggerHandler handler = new AbsenceDayTriggerHandler();
    if (Trigger.isUpdate && Trigger.isAfter) {
        handler.onAfterUpdate(Trigger.oldMap, Trigger.newMap);
    }
}