/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class CalloutRetryHandler_Test {

    @TestSetup
    static void setup(){
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User admin = new User(
            FirstName = 'Dummy',
            LastName = 'User',
            Alias = 'duser',
            Email = 'dummyuser@example.com',
            Username = 'dummyuser' + System.currentTimeMillis() + '@example.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        insert admin;
    }

    @isTest
    static void sendNotificationEmail() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            Test.startTest();
            CalloutRetryHandler.sendNotificationEmail('requestEndpoint', 'requestEndpoint','Test Email Body', 'Test Cause');
            Test.stopTest();

        }
    }

    @isTest
    static void test_scheduleRetry() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_createEmployeeAbscence_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            // Current DateTime
            DateTime now = System.now();

            // Add 5 minutes to the current time
            DateTime runTime = now.addMinutes(5);

            // Extract components for the cron expression
            Integer second = runTime.second();
            Integer minute = runTime.minute();
            Integer hour = runTime.hour();
            Integer day = runTime.day();
            Integer month = runTime.month();
            Integer year = runTime.year();

            // Generate the cron expression
            String cronExpression = String.format('{0} {1} {2} {3} {4} ? {5}', 
                new List<String>{String.valueOf(second), String.valueOf(minute), String.valueOf(hour), String.valueOf(day), String.valueOf(month), String.valueOf(year)});
            Test.startTest();
            CalloutRetryHandler.scheduleRetry('', '', '');
            Test.stopTest();
        }
    }

    @isTest
    static void test_queueable() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_createEmployeeAbscence_Success');
            mock.setStatusCode(201);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            CalloutRetryHandlerQueueable srhq = new CalloutRetryHandlerQueueable('requestEndpoint', 'requestMethod', 'body');
            System.enqueueJob(srhq);
            Test.stopTest();
        }
    }
}