This workspace was updated to follow a simple Clean Architecture layout:

- src/Domain: Entities and domain models
- src/Application: Use-cases, commands, interfaces
- src/Infrastructure.Messaging: MassTransit/RabbitMQ integration implementing Application interfaces
- src/Api: ASP.NET Core Web API, composes the application and infrastructure

The Blazor Client projects remain in the solution but were not modified here.

To build and run the API locally:
1. Start RabbitMQ (docker): docker compose up -d
2. cd src/Api
3. dotnet run

The API will publish messages via MassTransit to RabbitMQ.

This is a minimal scaffold; expand with persistence, authentication, DI modules, and tests as needed.