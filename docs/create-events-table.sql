CREATE TABLE
  /* Update your-project-name and your-dataset-name before running this query */
  `your-project-name.your-dataset-name.events` ( occurred_at TIMESTAMP NOT NULL OPTIONS(description="The timestamp at which the event occurred in the application."),
    event_type STRING NOT NULL OPTIONS(description="The type of the event, for example web_request. This determines the schema of the data which will be included in the data field."),
    user_id STRING OPTIONS(description="If a user was logged in when they sent a web request event that is this event, then this is the UID of this user."),
    request_uuid STRING OPTIONS(description="Unique ID of the web request, if this event is a web request event"),
    request_method STRING OPTIONS(description="Whether this web request was a GET or POST request, if this event is a web request event."),
    request_path STRING OPTIONS(description="The path, starting with a / and excluding any query parameters, of this web request, if this event is a web request"),
    request_user_agent STRING OPTIONS(description="The user agent of this web request, if this event is a web request. Allows a user's browser and operating system to be identified"),
    request_referer STRING OPTIONS(description="The URL of any page the user was viewing when they initiated this web request, if this event is a web request. This is the full URL, including protocol (https://) and any query parameters, if the browser shared these with our application as part of the web request. It is very common for this referer to be truncated for referrals from external sites."),
    request_query ARRAY < STRUCT <key STRING NOT NULL OPTIONS(description="Name of the query parameter e.g. if the URL ended ?foo=bar then this will be foo."),
    value ARRAY < STRING > OPTIONS(description="Contents of the query parameter e.g. if the URL ended ?foo=bar then this will be bar.") > > OPTIONS(description="ARRAY of STRUCTs, each with a key and a value. Contains any query parameters that were sent to the application as part of this web reques, if this event is a web request."),
    response_content_type STRING OPTIONS(description="Content type of any data that was returned to the browser following this web request, if this event is a web request. For example, 'text/html; charset=utf-8'. Image views, for example, may have a non-text/html content type."),
    response_status STRING OPTIONS(description="HTTP response code returned by the application in response to this web request, if this event is a web request. See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status."),
    DATA ARRAY < STRUCT <key STRING NOT NULL OPTIONS(description="Name of the field in the entity_table_name table in the database after it was created or updated, or just before it was imported or destroyed."),
    value ARRAY < STRING > OPTIONS(description="Contents of the field in the database after it was created or updated, or just before it was imported or destroyed.") > > OPTIONS(description="ARRAY of STRUCTs, each with a key and a value. Contains a set of data points appropriate to the event_type of this event. For example, if this event was an entity create, update, delete or import event, data will contain the values of each field in the database after this event took place - according to the settings in the analytics.yml configured for this instance of dfe-analytics. Value be anonymised as a one way hash, depending on configuration settings."),
    DATA_hidden ARRAY < STRUCT <key STRING NOT NULL OPTIONS(description="Name of the field in the entity_table_name table in the database after it was created or updated, or just before it was imported or destroyed."), 
    value ARRAY < STRING > OPTIONS(description="Contents of the field in the database after it was created or updated, or just before it was imported or destroyed.") > > OPTIONS(description="Defined in the same way as the DATA ARRAY of STRUCTs, except containing fields configured to be hidden in analytics_hidden_pii.yml")
    entity_table_name STRING OPTIONS(description="If event_type was an entity create, update, delete or import event, the name of the table in the database that this entity is stored in. NULL otherwise."),
    event_tags ARRAY < STRING > OPTIONS(description="Currently left blank for future use."),
    anonymised_user_agent_and_ip STRING OPTIONS(description="One way hash of a combination of the user's IP address and user agent, if this event is a web request. Can be used to identify the user anonymously, even when user_id is not set. Cannot be used to identify the user over a time period of longer than about a month, because of IP address changes and browser updates."),
    environment STRING OPTIONS(description="The application environment that the event was streamed from."),
    namespace STRING OPTIONS(description="The namespace of the instance of dfe-analytics that streamed this event. For example this might identify the name of the service that streamed the event.") )
PARTITION BY
  DATE(occurred_at)
CLUSTER BY
  event_type OPTIONS (description="Events streamed into the BigQuery from the application")
  /* You could add extra info here, like which environment and which application */
