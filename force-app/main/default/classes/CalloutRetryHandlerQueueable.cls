public with sharing class CalloutRetryHandlerQueueable implements Queueable, Database.AllowsCallouts {
    private String requestEndpoint;
    private String requestMethod;
    private String body;

    public CalloutRetryHandlerQueueable(String requestEndpoint, String requestMethod, String body) {
        this.requestEndpoint = requestEndpoint;
        this.requestMethod = requestMethod;
        this.body = body;
    }

    public void execute(QueueableContext context) {
        MSBCAPI.callAPI(requestEndpoint, requestMethod, body);       
    }
}