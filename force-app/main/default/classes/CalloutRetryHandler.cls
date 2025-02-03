public with sharing class CalloutRetryHandler implements Schedulable {
  //Add these the custom metadata setting
  private static final Integer DELAY_TIME_MINUTES = (Integer) MSBC_API_Configuration__mdt.getInstance('Dev').Delay_Time_in_Minutes__c; // Delay before retrying
  private static  String[] integrationUserEmails = MSBC_API_Configuration__mdt.getInstance('Dev').Emails_To_Notify__c.split(';'); // Email addresses to notify

  private String requestEndpoint;
  private String requestMethod;
  private String body;

	public void execute(SchedulableContext sc) {
    System.enqueueJob(new CalloutRetryHandlerQueueable(requestEndpoint, requestMethod, body));
  }

  public static void scheduleRetry(String requestEndpoint, String requestMethod, String body) {
    // Current DateTime
    DateTime now = System.now();

    // Add 5 minutes to the current time
    DateTime runTime = now.addMinutes(DELAY_TIME_MINUTES);

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

    System.schedule('Retry Callout Job - ' + cronExpression, cronExpression, new CalloutRetryHandler(requestEndpoint, requestMethod, body));
  }

  public CalloutRetryHandler(String requestEndpoint, String requestMethod, String body) {
    this.requestEndpoint = requestEndpoint;
    this.requestMethod = requestMethod;
    this.body = body;
  }

  public static void sendNotificationEmail(String requestEndpoint, String requestMethod, String body, String cause) {
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(integrationUserEmails);
    mail.setSubject('An error occur when accessing MSBC API');     
    String emailBody = '<html><body>' +
      '<p>' + 'The callout to : ' + requestEndpoint + ' failed' + '</p>' +    	
      '<p>' + 'Please check the logs in Nebula Logger ' + '</p>' + 
      '<p>' + 'The request method is: ' + requestMethod + '</p>' +  
      '<p>' + 'The request body is: ' + body + '</p>' +
      '<p>' + 'Cause: ' + cause + '</p>' +
      '</body></html>'; 
    mail.setHtmlBody(emailBody);
    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });  
  }
}