public with sharing class TimeEntries_ScheduleBatch implements Database.Batchable<MSBCAPI.Header> , Database.Stateful , Database.AllowsCallouts , Schedulable { 
  Integer numberOfHeaders = 0;
  private String originalTransactionId;

  public Iterable<MSBCAPI.Header> start(Database.BatchableContext info){
    this.originalTransactionId = Logger.getTransactionId();

    Logger.info('Starting TimeEntries_ScheduleBatch');
    Logger.saveLog();
  
    return new MSBCAPI_HeaderIterable();
  }

  public void execute(Database.BatchableContext info, List<MSBCAPI.Header> scope){
    Logger.setParentLogTransactionId(this.originalTransactionId);

		flair__Time_Entry__c[] timeEntries = new List<flair__Time_Entry__c>();
    Set<String> ERP_ResourceNumbers = new Set<String>();
    Map<String, Decimal> breakTimesByHeaderIds = new Map<String, Decimal>();
    for(MSBCAPI.Header header : scope){
      ERP_ResourceNumbers.add(header.resNo);
    }

    Map<String, Id> employeeMap = new Map<String, Id>();
    for(flair__Employee__c employee : [SELECT Id, ERP_Resource_No__c FROM flair__Employee__c WHERE ERP_Resource_No__c IN :ERP_ResourceNumbers]){
      employeeMap.put(employee.ERP_Resource_No__c, employee.Id);
    }

    for(MSBCAPI.Header header : scope){
      flair__Time_Entry__c timeEntry = new flair__Time_Entry__c();
      timeEntry.flair__Employee__c = employeeMap.get(header.resNo);
      timeEntry.flair__Migration_ID__c = header.id;
      timeEntry.flair__Start_Datetime__c = Datetime.valueOf(header.xdate + ' ' + header.fromTime);
      timeEntry.flair__End_Datetime__c =  Datetime.valueOf(header.xdate + ' ' + header.toTime);
      timeEntry.flair__Approval_Status__c = 'PENDING';
      timeEntries.add(timeEntry);
      breakTimesByHeaderIds.put(header.id, header.breakTime);
    }

    numberOfHeaders += scope.size();
    Database.UpsertResult[] timeEntriesResults = Database.upsert(timeEntries, flair__Time_Entry__c.flair__Migration_ID__c, true, AccessLevel.SYSTEM_MODE);
    Logger.info('Processed time entry records', timeEntriesResults);

		flair__Time_Entry_Break__c[] timeBreaks = new List<flair__Time_Entry_Break__c>();
    for(flair__Time_Entry__c  timeEntry : [SELECT Id, flair__Start_Datetime__c, flair__Migration_ID__c FROM flair__Time_Entry__c WHERE flair__Migration_ID__c IN :breakTimesByHeaderIds.keySet()]){
      flair__Time_Entry_Break__c timeBreak = new flair__Time_Entry_Break__c();
      timeBreak.flair__Time_Entry__c = timeEntry.Id;
      timeBreak.flair__Migration_ID__c = timeEntry.flair__Migration_ID__c;
      timeBreak.flair__Start_Datetime__c = timeEntry.flair__Start_Datetime__c;
      timeBreak.flair__End_Datetime__c = timeEntry.flair__Start_Datetime__c.addMinutes((breakTimesByHeaderIds.get(timeEntry.flair__Migration_ID__c) * 60 ).intValue());
      timeBreaks.add(timeBreak);
    }
    
    Database.UpsertResult[] timeBreaksResults = Database.upsert(timeBreaks, flair__Time_Entry_Break__c.flair__Migration_ID__c, true, AccessLevel.SYSTEM_MODE);
    Logger.info('Processed time entry break records', timeBreaksResults);

    Map<String, flair__Time_Entry__c> timeEntriesProcessedMap = new Map<String, flair__Time_Entry__c>();
    flair__Time_Entry__c[] timeEntriesToDelete = new List<flair__Time_Entry__c>();
    for(flair__Time_Entry__c  timeEntry : [SELECT Id, flair__Start_Datetime__c, flair__Employee__r.ERP_Resource_No__c, CreatedDate FROM flair__Time_Entry__c WHERE flair__Employee__c IN :employeeMap.values()]) {
      String key = timeEntry.flair__Employee__r.ERP_Resource_No__c + timeEntry.flair__Start_Datetime__c.format('yyyy-MM-dd');
      if (!timeEntriesProcessedMap.containsKey(key)) {
        timeEntriesProcessedMap.put(key, timeEntry);
      } else {
        if(timeEntriesProcessedMap.get(key).CreatedDate <= timeEntry.CreatedDate) {
          timeEntriesToDelete.add(timeEntriesProcessedMap.get(key));
          timeEntriesProcessedMap.put(key, timeEntry);
        } else {
          timeEntriesToDelete.add(timeEntry);
        }
      }
    }

    Logger.info('Kept time entries', timeEntriesProcessedMap.values());
    Database.DeleteResult[] timeEntryDeleteResults = Database.delete(timeEntriesToDelete, true, AccessLevel.SYSTEM_MODE);
    Logger.info('Delete time entry records', timeEntryDeleteResults);
    Logger.saveLog();
  }

  public void finish(Database.BatchableContext info){
    Logger.info('Number of Headers processed: ' + numberOfHeaders);
    Logger.setParentLogTransactionId(this.originalTransactionId);
    Logger.info('Finishing running TimeEntries_ScheduleBatch');
    Logger.saveLog();
  }

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new TimeEntries_ScheduleBatch());
  }

  public static void start(){
    String jobName = 'EmployeeAbsences_ScheduleBatch' + ' - ' + Datetime.now().format();
    String cron = '0 0 1 ? * *'; //Every day at 1:AM hour
		Logger.info('Scheduling TimeEntries_ScheduleBatch with cron: ' + cron);
    System.schedule(jobName, cron, new EmployeeAbsences_ScheduleBatch());
  }
}