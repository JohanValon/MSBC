public with sharing class CalloutRetryHandlerQueueable implements Queueable, Database.AllowsCallouts {
  private String requestEndpoint;
  private String requestMethod;
  private String body;
	private Integer currentAttempt;


  public CalloutRetryHandlerQueueable(String requestEndpoint, String requestMethod, String body) {
    this.requestEndpoint = requestEndpoint;
    this.requestMethod = requestMethod;
    this.body = body;
		this.currentAttempt = 1;
  }

  public void execute(QueueableContext context) {
		Http http = new Http();
		HttpRequest request = new HttpRequest();
		request.setEndpoint(requestEndpoint);
		request.setMethod(requestMethod);
		
		if (body != null) {
			request.setBody(body);
			request.setHeader('Content-Type', 'application/json');
		}
		HttpResponse response = http.send(request);
		try {
			if (String.valueOf(response.getStatusCode()).startsWith('20')) {
				Logger.info('Callout succeeded: ' + response.getStatusCode());
				return response;
			} else {
				Logger.error('An error occured while calling the API').setMessage(String.valueOf(response.getStatusCode())).setMessage(response.getStatus()).setMessage(response.getBody());
				// retryCount++;
				
				if( new List<Integer>{400, 401, 403, 404}.contains(response.getStatusCode())){
					Logger.error('No retry sever error. Callout failed.');
					sendNotificationEmail(requestEndpoint, requestMethod, body, response.getBody());
					throw new CalloutException(response.getBody());
				} else {
					//  if (retryCount < MAX_RETRIES) {
					// 	// Schedule the retry after the delay time
						// Logger.info('Number of Retries : ' + retryCount);
						handleRetry(context);
					// 	// CalloutRetryHandler.scheduleRetry(requestEndpoint, requestMethod, body);
					// } else {
					// 	Logger.error('Max retries reached. Callout failed.');
					// 	sendNotificationEmail(requestEndpoint, requestMethod, body, response.getBody());
					// 	throw new CalloutException(response.getBody());
					// }
				}
			}
		} catch (Exception ex) {
			Logger.error('An error while calling the API').setMessage(ex.getMessage());
			handleRetry(context);
		}
  }

	private void handleRetry(QueueableContext context) {
    if (currentAttempt < MAX_ATTEMPTS) {
      currentAttempt++;
      String cronExpression = getCronExpression();
			Logger.info('Number of Retries : ' + currentAttempt);
      System.schedule('Retry Callout Attempt : ' + currentAttempt, cronExpression, new CalloutRetryHandlerQueueable(requestEndpoint, requestMethod, body));
      // scheduleRetry(requestEndpoint, requestMethod, body);
    } else {
      Logger.error('All attempts failed').setMessage('The callout to : ' + requestEndpoint + ' failed');
			sendNotificationEmail(requestEndpoint, requestMethod, body, response.getBody());
    }
  }

	private String getCronExpression(){
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
    return String.format('{0} {1} {2} {3} {4} ? {5}', 
      new List<String>{String.valueOf(second), String.valueOf(minute), String.valueOf(hour), String.valueOf(day), String.valueOf(month), String.valueOf(year)});
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