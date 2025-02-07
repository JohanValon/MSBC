public with sharing class AbsenceDayTriggerHandler {
  public AbsenceDayTriggerHandler() {}

  public void onAfterUpdate(Map<Id, flair__Absence_Day__c> oldAbsenceDays, Map<Id, flair__Absence_Day__c> newAbsenceDays) {
    Set<Id> oldAbsenceIds = new Set<Id>();
    Set<Id> newAbsenceIds = new Set<Id>();
    for(flair__Absence_Day__c absenceDay : oldAbsenceDays.values()) {
      oldAbsenceIds.add(absenceDay.Id);
    }
    for(flair__Absence_Day__c absenceDay : newAbsenceDays.values()) {
      newAbsenceIds.add(absenceDay.Id);
    }
    // AbsenceTriggerHandler.deleteRelatedEmployeeAbsencesInMSBC(oldAbsenceIds);
    // AbsenceTriggerHandler.createRelatedEmployeeAbsencesInMSBC(newAbsenceIds);
		ChainManager.instance
    .add(new FutureLink_deleteEmployeeAbsencesInMSBC(oldAbsenceIds))
    .add(new FutureLink_createEmployeeAbsencesInMSBC(newAbsenceIds))
    .startChain();
  }
}