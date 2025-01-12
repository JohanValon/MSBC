public with sharing class TimeEntries_ScheduleBatch implements Database.Batchable<MSBCAPI.Header> , Database.Stateful , Database.AllowsCallouts , Schedulable { 
    Integer numberOfHeaders = 0;
    public Iterable<MSBCAPI.Header> start(Database.BatchableContext info){
        return new MSBCAPI_HeaderIterable();
    }

    public void execute(Database.BatchableContext info, List<MSBCAPI.Header> scope){
        List<flair__Time_Entry__c> timeEntries = new List<flair__Time_Entry__c>();
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
        upsert timeEntries flair__Migration_ID__c;

        List<flair__Time_Entry_Break__c> timeBreaks = new List<flair__Time_Entry_Break__c>();
        for(flair__Time_Entry__c  timeEntry : [SELECT Id, flair__Start_Datetime__c, flair__Migration_ID__c FROM flair__Time_Entry__c WHERE flair__Migration_ID__c IN :breakTimesByHeaderIds.keySet()]){
            flair__Time_Entry_Break__c timeBreak = new flair__Time_Entry_Break__c();
            timeBreak.flair__Time_Entry__c = timeEntry.Id;
            timeBreak.flair__Start_Datetime__c = timeEntry.flair__Start_Datetime__c;
            timeBreak.flair__End_Datetime__c = timeEntry.flair__Start_Datetime__c.addMinutes((breakTimesByHeaderIds.get(timeEntry.flair__Migration_ID__c) * 60 ).intValue());
            timeBreaks.add(timeBreak);
        }
        insert timeBreaks;
    }

    public void finish(Database.BatchableContext info){
        System.debug('Number of Headers processed: ' + numberOfHeaders);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TimeEntries_ScheduleBatch());
    }

    public static void start(){
        String jobName = 'EmployeeAbsences_ScheduleBatch' + ' - ' + Datetime.now().format();
        String cron = '0 0 1 ? * *'; //Every day at 1:AM hour
        System.schedule(jobName, cron, new EmployeeAbsences_ScheduleBatch());
    }
}