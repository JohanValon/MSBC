public with sharing class CalloutRetryHandler implements Schedulable, Database.AllowsCallouts {

  // private static final Integer MAX_RETRIES = 3;
  private static final Integer DELAY_TIME_MINUTES = 5; // Delay before retrying

  private String requestEndpoint;
  private String requestMethod;
  private String body;
	private Integer retryCount;


  // public CalloutRetryHandler(String requestEndpoint, String requestMethod, String body, Integer retryCount) {
  //   this.retryCount = retryCount;
	// 	this.requestEndpoint = requestEndpoint;
	// 	this.requestMethod = requestMethod;
	// 	this.body = body;
  // }

  // public void execute(QueueableContext context) {
  //   HttpResponse response = makeHttpCallout( requestEndpoint, requestMethod, body);

  //   if (response != null) {
  //     handleResponse(response);
  //   } else {
  //     System.debug('No response received from the callout.');
  //   }
  // }

  // public static HttpResponse makeHttpCallout(String requestEndpoint, String requestMethod, String body) {
  //   Http http = new Http();
  //   HttpRequest request = new HttpRequest();
  //   request.setEndpoint(requestEndpoint);
  //   request.setMethod(requestMethod);

	// 	if (body != null) {
  //     request.setBody(body);
  //     request.setHeader('Content-Type', 'application/json');
  //   }

  //   try {
  //     return http.send(request);
  //   } catch (System.CalloutException e) {
  //     System.debug('Callout failed: ' + e.getMessage());
  //     return null;
  //   }
  // }

  // private void handleResponse(HttpResponse response) {
  //   if (response.getStatusCode() == 400) {
  //     if (retryCount < MAX_RETRIES) {
  //       scheduleRetry();
  //     } else {
  //       System.debug('Max retry attempts reached. Response Code: ' + response.getStatusCode());
  //     }
  //   } else {
  //     System.debug('Successful Response Code: ' + response.getStatusCode());
  //     // Handle other status codes as needed
  //   }
  // }

  // private void scheduleRetry() {
  //   retryCount++;
  //   System.schedule('Retry Callout Job - Attempt ' + retryCount, '0 0/' + DELAY_MINUTES + ' * * ? *', new CalloutRetryHandler(retryCount));
  // }
	public void execute(SchedulableContext sc) {
    MSBCAPI.callAPI(requestEndpoint, requestMethod, body);
  }

  public static void scheduleRetry(String requestEndpoint, String requestMethod, String body) {
    System.schedule('Retry Callout Job', '0 0/' + DELAY_TIME_MINUTES + ' * * ? *', new CalloutRetryHandler(requestEndpoint, requestMethod, body));
  }

  public CalloutRetryHandler(String requestEndpoint, String requestMethod, String body) {
    this.requestEndpoint = requestEndpoint;
    this.requestMethod = requestMethod;
    this.body = body;
  }
}