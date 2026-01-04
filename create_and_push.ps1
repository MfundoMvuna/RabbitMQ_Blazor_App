param(
    [string]$Owner = "MfundoMvuna",
    [string]$Repo = "RabbitMQ_Blazor_App",
    [string]$Branch = "main",
    [string]$CommitMessage = "Initial commit: Blazor + OpenIddict + MassTransit + RabbitMQ demo",
    [string]$Remote = ""
)

if (-not $Remote) {
    $Remote = "https://github.com/$Owner/$Repo.git"
}

$Dir = $Repo

if (Test-Path $Dir) {
    Write-Error "Directory $Dir already exists. Remove or move it and re-run."
    exit 1
}

New-Item -Path $Dir -ItemType Directory | Out-Null
Set-Location -Path $Dir

# Files dictionary: key = path, value = file content (here-strings)
$files = @{}

$files['docker-compose.yml'] = @'
version: "3.8"
services:
  rabbitmq:
    image: rabbitmq:3.11-management
    hostname: rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: "guest"
      RABBITMQ_DEFAULT_PASS: "guest"
    ports:
      - "5672:5672"
      - "15672:15672"
    healthcheck:
      test: ["CMD", "rabbitmqctl", "status"]
      interval: 10s
      timeout: 5s
      retries: 5
'@

$files['README.md'] = @'
# RabbitMQ + .NET 8 + Blazor + OpenIddict + MassTransit — Demo

This repository is a demo starter showing:
- Blazor WebAssembly frontend using Authorization Code + PKCE (OpenID Connect).
- ASP.NET Core Web API acting as:
  - OpenIddict authorization server (demo, backed by EF InMemory/Identity).
  - Protected API endpoints (require authenticated users).
  - MassTransit publisher that sends messages to RabbitMQ.
  - MassTransit consumer that processes messages, with retry, error handling and dead-lettering.
- Docker Compose to run RabbitMQ with management UI.
- GitHub Actions CI for build & test.
- xUnit tests demonstrating publish flow (MassTransit TestHarness).

Important: This is a demo project intended for learning and prototyping. Do NOT use the in-memory EF provider or default secrets in production. For production, use a persistent DB (Postgres/SQL Server), securely store keys, use HTTPS, and a hardened identity provider (or OpenIddict with a proper DB and key management) or an external OIDC provider.

Quick start (development)
1. Start RabbitMQ:
   docker compose up -d

2. Run API:
   cd src/Api
   dotnet run

   The API will run at https://localhost:5001 and exposes:
   - OpenIddict endpoints (/.well-known/openid-configuration, /connect/authorize, /connect/token, etc.)
   - API endpoints at /api/*

3. Run Blazor client:
   cd src/BlazorClient
   dotnet run

4. Browse:
   - Blazor client: https://localhost:7290 (port shown when running)
   - RabbitMQ management UI: http://localhost:15672 (guest/guest)

Demo credentials
- Register a user using the account endpoints from the API (or use the UI register page).
- A demo client application is pre-registered in OpenIddict with:
  - ClientId: blazor_client
  - Redirect URI: https://localhost:7290/authentication/login-callback

What’s included
- src/Api: ASP.NET Core Web API with OpenIddict + Identity + MassTransit
- src/BlazorClient: Blazor WASM client configured for OIDC (Authorization Code + PKCE)
- src/Tests: xUnit tests with MassTransit TestHarness
- docker-compose.yml for RabbitMQ
- .github/workflows/ci.yml for build & test

Next steps (suggested)
- Replace EF InMemory with a persistent database and run migrations.
- Use production-safe keys (persisted certificates or Azure KeyVault).
- Harden Identity and consider email verification, password policies, MFA.
- Move OpenIddict to a dedicated authorization server for production, or integrate a full provider (Azure AD, Keycloak, Duende, Auth0).
- Add TLS for RabbitMQ and broker-side auth if needed.
'@

$files['.github/workflows/ci.yml'] = @'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: 8.0.x

      - name: Restore
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore -c Release

      - name: Run tests
        run: dotnet test --no-build -c Release --logger "trx"
'@

# Add remaining project and source files (truncated here in explanation)
# For brevity I will add the rest of the files exactly as in your bash script:
$files['src/Api/Api.csproj'] = @'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Identity.EntityFrameworkCore" Version="8.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="8.0.0" />
    <PackageReference Include="OpenIddict.AspNetCore" Version="4.5.0" />
    <PackageReference Include="OpenIddict.EntityFrameworkCore" Version="4.5.0" />
    <PackageReference Include="MassTransit.AspNetCore" Version="8.0.6" />
    <PackageReference Include="MassTransit.RabbitMQ" Version="8.0.6" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.7.0" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="8.0.0" />
  </ItemGroup>
</Project>
'@

$files['src/Api/appsettings.json'] = @'
{
  "OpenIddict": {
    "Authority": "https://localhost:5001",
    "ClientId": "blazor_client",
    "ClientRedirectUri": "https://localhost:7290/authentication/login-callback"
  },
  "MassTransit": {
    "RabbitMqHost": "localhost",
    "Username": "guest",
    "Password": "guest",
    "VirtualHost": "/"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "MassTransit": "Information"
    }
  },
  "AllowedHosts": "*"
}
'@

$files['src/Api/Program.cs'] = @'
using System.Security.Claims;
using MassTransit;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using OpenIddict.Abstractions;
using OpenIddict.EntityFrameworkCore.Models;
using DemoApi;
using DemoApi.Identity;
using DemoApi.Messaging;

var builder = WebApplication.CreateBuilder(args);

// Load config
builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);

// Add DbContext (InMemory for demo)
builder.Services.AddDbContext<ApplicationDbContext>(options =>
{
    options.UseInMemoryDatabase("demo-db");
    // Register the OpenIddict entity sets.
    options.UseOpenIddict();
});

// Add Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// OpenIddict (authorization server + token endpoint)
builder.Services.AddOpenIddict()
    .AddCore(options =>
    {
        options.UseEntityFrameworkCore()
               .UseDbContext<ApplicationDbContext>();
    })
    .AddServer(options =>
    {
        options.AllowAuthorizationCodeFlow()
               .RequireProofKeyForCodeExchange();

        options.SetAuthorizationEndpointUris("/connect/authorize")
               .SetTokenEndpointUris("/connect/token")
               .SetUserinfoEndpointUris("/connect/userinfo");

        // Use ephemeral keys for demo (replace with persistent keys in production)
        options.AddDevelopmentEncryptionCertificate()
               .AddDevelopmentSigningCertificate();

        options.RegisterScopes(OpenIddictConstants.Scopes.Email, OpenIddictConstants.Scopes.Profile, "api");

        // Register the ASP.NET Core host and configure endpoints
        options.UseAspNetCore()
               .EnableTokenEndpointPassthrough()
               .EnableAuthorizationEndpointPassthrough()
               .EnableUserinfoEndpointPassthrough();
    })
    .AddValidation(options =>
    {
        // Configure the OpenIddict validation handler to use the local server instance
        options.UseLocalServer();
        options.UseAspNetCore();
    });

// MassTransit with RabbitMQ
var mtCfg = builder.Configuration.GetSection("MassTransit");
string rabbitHost = mtCfg.GetValue<string>("RabbitMqHost") ?? "localhost";
string rabbitUser = mtCfg.GetValue<string>("Username") ?? "guest";
string rabbitPass = mtCfg.GetValue<string>("Password") ?? "guest";
string virtualHost = mtCfg.GetValue<string>("VirtualHost") ?? "/";

builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<DemoMessageConsumer>(cfg =>
    {
        // consumer configuration if needed
    });

    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(rabbitHost, virtualHost, h =>
        {
            h.Username(rabbitUser);
            h.Password(rabbitPass);
        });

        cfg.ReceiveEndpoint("demo-queue", e =>
        {
            e.ConfigureConsumer<DemoMessageConsumer>(context);

            // Use durable queue, limit concurrency and add retry
            e.PrefetchCount = 16;
            e.UseMessageRetry(r => r.Interval(3, TimeSpan.FromSeconds(2)));
            // Configure dead-lettering via separate error queue (MassTransit handles error queues automatically)
        });
    });
});

// Simple JWT authentication for API calls to protect non-OAuth endpoints (optional)
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(options =>
{
    options.Authority = builder.Configuration["OpenIddict:Authority"] ?? "https://localhost:5001";
    options.RequireHttpsMetadata = true;
    options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
    {
        ValidateAudience = false
    };
});

// Application services
builder.Services.AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>, AdditionalUserClaimsPrincipalFactory>();

var app = builder.Build();

// Seed demo OpenIddict client and a demo user
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    // Ensure DB created
    db.Database.EnsureCreated();

    // Seed OpenIddict client and demo user
    var manager = scope.ServiceProvider.GetRequiredService<OpenIddictApplicationManager<OpenIddictEntityFrameworkCoreApplication>>();
    var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

    // Register client if not exists
    var clientId = "blazor_client";
    if (await manager.FindByClientIdAsync(clientId) is null)
    {
        var descriptor = new OpenIddictApplicationDescriptor
        {
            ClientId = clientId,
            DisplayName = "Blazor Client",
            RedirectUris = { new Uri(builder.Configuration["OpenIddict:ClientRedirectUri"]!) },
            Permissions =
            {
                OpenIddictConstants.Permissions.Endpoints.Authorization,
                OpenIddictConstants.Permissions.Endpoints.Token,
                OpenIddictConstants.Permissions.Endpoints.Userinfo,
                OpenIddictConstants.Permissions.GrantTypes.AuthorizationCode,
                OpenIddictConstants.Permissions.ResponseTypes.Code,
                OpenIddictConstants.Permissions.Scopes.Email,
                OpenIddictConstants.Permissions.Scopes.Profile,
                "api"
            }
        };
        await manager.CreateAsync(descriptor);
    }

    // Seed demo user
    var demoUser = await userManager.FindByNameAsync("alice");
    if (demoUser is null)
    {
        var user = new ApplicationUser { UserName = "alice", Email = "alice@example.com" };
        var r = await userManager.CreateAsync(user, "Pass123!");
        if (!r.Succeeded) throw new Exception("Failed to create demo user");
    }
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
'