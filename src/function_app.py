import datetime
import logging
import azure.functions as func

app = func.FunctionApp()

@app.function_name(name="TimerTrigger")
@app.schedule(schedule="0 */2 * * * *",
              arg_name="mytimer",
              run_on_startup=False)
@app.event_hub_output(arg_name="event",
                      event_hub_name="%EventHubName%",
                      connection="EventHubConnection")
def timer_eventhub_function(mytimer: func.TimerRequest, event: func.Out[str]):
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()
    
    if mytimer.past_due:
        logging.info('The timer is past due!')
    
    logging.info(f"Timer trigger function ran at {utc_timestamp}.")
    event.set(f"Timer trigger function ran at {utc_timestamp}.")


@app.function_name(name="HttpTrigger")
@app.route(route="hello")
def http_function(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('HTTP trigger function processed a request.')

    name = req.params.get('name')

    return func.HttpResponse(f"Hello, {name}!  HttpTrigger function processed a request!", status_code=200)


@app.function_name(name="EventHubTrigger")
@app.event_hub_message_trigger(arg_name="myhub",
                               event_hub_name="%EventHubName%",
                               connection="EventHubConnection")
def event_hub_function(myhub: func.EventHubEvent):
    logging.info(f"Event Hub trigger processed an event: {myhub.get_body().decode('utf-8')}")
