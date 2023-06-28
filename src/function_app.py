import azure.functions as func
import logging

app = func.FunctionApp()


@app.function_name(name="HttpTrigger1")
@app.route(route="hello")
def test_function(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')

    return func.HttpResponse(f"Hello, {name}!  HttpTrigger1 function processed a request!", status_code=200)


@app.function_name(name="EventHubTrigger1")
@app.event_hub_message_trigger(arg_name="myhub",
                               event_hub_name="widgets",
                               connection="EventHubConnection")
def event_hub_function(myhub: func.EventHubEvent):
    logging.info('Python EventHub trigger processed an event: %s',
                 myhub.get_body().decode('utf-8'))
