using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DocumentModel;
using Amazon.Lambda.Core;
using Amazon.Lambda.Serialization.SystemTextJson;
using Amazon.Lambda.SNSEvents;
using HotelCreatedEventHandler.Models;
using OpenSearch.Client;
using System.Text.Json;

[assembly: LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]

namespace HotelCreatedEventHandler;

public class HotelCreatedEventHandler
{
    public async Task Handler(SNSEvent snsEvent)
    {
        Console.WriteLine("Lambda was invoked from SNS.");
        var dbClient = new AmazonDynamoDBClient();
        var table = Table.LoadTable(dbClient, "hotel-created-event-ids");

        var host = Environment.GetEnvironmentVariable("host");
        Console.WriteLine($"Host Name: {host}");

        var userName = Environment.GetEnvironmentVariable("userName");
        Console.WriteLine($"User Name: {userName}");

        var password = Environment.GetEnvironmentVariable("password");

        var indexName = Environment.GetEnvironmentVariable("indexName");
        Console.WriteLine($"Index Name: {indexName}");

        var settings = new ConnectionSettings(
                    new Uri(host))
                    .DefaultIndex(indexName)
                    .BasicAuthentication(userName, password)
                    .DefaultMappingFor<Hotel>(m => m.IdProperty(p => p.Id));

        var esClient = new OpenSearchClient(settings);

        if (!(await esClient.Indices.ExistsAsync(indexName)).Exists) await esClient.Indices.CreateAsync(indexName);

        Console.WriteLine($"Found {snsEvent.Records.Count} records in SNS Event");

        foreach (var eventRecord in snsEvent.Records)
        {
            var eventId = eventRecord.Sns.MessageId;
            var foundItem = await table.GetItemAsync(eventId);
            if (foundItem == null)
                await table.PutItemAsync(new Document
                {
                    ["eventid"] = eventId
                });

            Console.WriteLine($"Message data : {eventRecord.Sns.Message}");

            var hotel = JsonSerializer.Deserialize<Hotel>(eventRecord.Sns.Message);

            var response = esClient.IndexDocumentAsync<Hotel>(hotel);

            if (response != null)
            {
                Console.WriteLine($"Debug Information :: {response.IsCompletedSuccessfully}");

                if (response.Result.Result == Result.Error)
                {
                    if (response.Result.ServerError != null)
                    {
                        Console.WriteLine($"Server Error:{response.Result.ServerError}");
                    }
                    else if (response.Result.ServerError.Error != null)
                    {
                        Console.WriteLine($"Server Error Reason:{response.Result.ServerError.Error.Reason}");
                    }
                    else
                    {
                        Console.WriteLine($"Server Error is null");
                    }
                }
            }
            else
            {
                Console.WriteLine("Response object is null");
            }
        }
    }
}