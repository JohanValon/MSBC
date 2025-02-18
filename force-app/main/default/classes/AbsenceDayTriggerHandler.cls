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

    if(!System.isBatch()) {
      ChainManager.instance
      .add(new AbsenceTriggerHandler.DeleteRelatedEmployeeAbsencesInMSBC(oldAbsenceIds, oldAbsenceDays.keySet()))
      .add(new AbsenceTriggerHandler.CreateRelatedEmployeeAbsencesInMSBC(newAbsenceIds, oldAbsenceDays.keySet()))
      .startChain();
    }
  }
}