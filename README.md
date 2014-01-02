# Resque::Clues

Resque-Clues allows Resque to publish job lifecycle events to some external
store for searching & visualization to assist:

* Performance analysis & tuning
* Production debugging/support
* SLA measurement
* Arbitrary, context-specific data spelunking

This gem simply surfaces this data, and it is left up to other tools using
the external data store to search and/or visualize the data.  Some examples
of other technologies that can be used to visualize this data would be 
[Splunk](http://www.splunk.com/), [Cube](http://corner.squareup.com/2011/09/cube.html)
and [Logstash](http://logstash.net/) with [Graphite](http://graphite.wikidot.com/).
Coupled with those tools, resque clues will enable you to create views into 
your background processes like the following:

![splunk dashboard](http://i.imgur.com/0sZEw1L.png?1)

## Lifecycle events

Four lifecycle events will be published for each job entering a queue:

1. enqueued
2. dequeued
3. perform_started
4. perform_finished -or- failed

Each will contain the following minimum information:

* event_type: Either enqueued, dequeued, perform_started, perform_finished or
  failed.
* event_hash: Unique hash grouping all events associated with a single 
  background job.
* worker_class: The job class that contains the perform logic.
* queue: The queue the job is placed into.
* timestamp: The time the event occurs.
* hostname: The hostname of the machine where the event originates from.
* process: The process on the host machine where the event originates from.
* args: The arguments passed to the perform method.

dequeued events will also include time_in_queue, which is the amount of time
the job spent in the queue. The perform_finished and failed events will include
time_to_perform, which is the time it took to perform the job after it was
dequeued.  Failed events will include the exception class, the exception
message and a backtrace.

## Basic Usage

Require the gem in your Gemfile, then wire up the publisher's used to publish
these resque events as so:

```ruby
require 'resque'
require 'resque-clues'

publisher = Resque::Plugins::Clues::LogPublisher.new("/var/log/resque-clues.log")
Resque::Plugins::Clues.event_publisher = publisher
```

This needs to occur before any Resque work is done, both on the enqueing or 
dequeing side.  In a rails application, this code is best placed in an 
initializer.

Note that this is using a LogPublisher, which will write the events to a log
file, which can be indexed using Splunk or Logstash.  You can use an existing
log publisher (```StandardOutPublisher```, ```LogPublisher```, 
```CompositePublisher```) or write your own.

## Searching & Visualizing Event Data
This is dependent on your tool of choice.  Resque Clues simply publishes the events
in a JSON format (by default), and they will then need to be consumed as appropriate
by your search/visualization tool.  At PeopleAdmin, we already were using (and paying
for) Splunk so we went this route.  Our set up using Splunk required:

1.  Wiring Resque Clues into our app and publishing events to a log file.
2.  Setting up Splunk forwarders on our worker boxes to send the log events to a Splunk server.
3.  Setting up saved searches and dashboards as needed within Splunk.

To search for all events related to a specific job that enters your background queue,
its best to key in on a date rangee, job class and event type.  Once you find one 
event associated with a run of a job, you can search on its unique ```event_hash```
to find all of its related events.  This allows you to specifically see exactly what
happened to any job entering your background queues.

## Surfacing Other Data

The above works to surface backgrounding data as described in the lifecycle events
section.  But you may want to break down your data along other axis.  To accomplish 
this, you need to use an item preprocessor, which is just a block invoked before
enqueing the job to further decorate the item stored in redis:

```ruby
Resque::Plugins::Clues.item_preprocessor = proc do |queue, item| 
  item[:metadata][:customer_id] = Customer.current.id
end
```

The item is a hash using string keys.  Its structure is as follows:

```ruby
{
  'class' => 'SomeJob',
  'args' => [1,2,3],
  'clues_metadata' => {}
}
```

Whatever additional data you want to track should be injected into the item's 
```clues_metadata``` hash, and will be included in all other downstream events
for a job.  This wiring codealso needs to be executed prior to any jobs being
enqueued or dequeuend within the application code, such as a Rails initializer.

## Event Format
By default, resque clues publishes events in a JSON format using an event marshaller.
The marshaller is just a lambda that formats input data appopriately, and you can
write your own as long as it has the following signature.

```ruby
lambda do |event_type, timestamp, queue, metadata, worker_class, args|
  # something that returns a string
end
```

Here is n example of a resque clues event as marshalled to JSON:

```
{
  "event_type":"dequeued",
  "timestamp":"2013-06-04T20:59:58Z",
  "queue":"test_queue",
  "metadata": {
    "event_hash":"0695f49c5e70fc18da91961113e1769a"
    "hostname":"Lances-MacBook-Air.local",
    "process":30731
  },
  "worker_class":"TestWorker",
  "args":[1,2]
}
```

## Future
Here are some things we'd like to tackle in the future:

* TCP/IP log publisher
* UDP log publisher
* An easily deployable, open-source visualization solution, probably based on logstash & graphite with some precanned searches and visualizations.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
