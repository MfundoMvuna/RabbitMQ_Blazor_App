using Api.Registration;
using Infrastructure.Persistence.Registration;
using OpenIddict.Abstractions;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Centralized registrations
builder.Services.AddApplicationServices();
builder.Services.AddInfrastructureMessaging();
builder.Services.AddPersistenceServices();

var app = builder.Build();

// Seed demo OpenIddict client and a demo user
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<Infrastructure.Persistence.ApplicationDbContext>();
    db.Database.EnsureCreated();

    //var manager = scope.ServiceProvider.GetRequiredService<OpenIddict.Abstractions.IOpenIddictApplicationManager<OpenIddict.EntityFrameworkCore.Models.OpenIddictEntityFrameworkCoreApplication>>();
    var manager = scope.ServiceProvider.GetRequiredService<IOpenIddictApplicationManager>();
    var userManager = scope.ServiceProvider.GetRequiredService<Microsoft.AspNetCore.Identity.UserManager<Infrastructure.Persistence.Identity.ApplicationUser>>();

    var clientId = "blazor_client";
    if (await manager.FindByClientIdAsync(clientId) is null)
    {
        var descriptor = new OpenIddict.Abstractions.OpenIddictApplicationDescriptor
        {
            ClientId = clientId,
            DisplayName = "Blazor Client",
            RedirectUris = { new Uri("https://localhost:7290/authentication/login-callback") },
            Permissions =
            {
                OpenIddict.Abstractions.OpenIddictConstants.Permissions.Endpoints.Authorization,
                OpenIddict.Abstractions.OpenIddictConstants.Permissions.Endpoints.Token,
                //OpenIddict.Abstractions.OpenIddictConstants.Permissions.Endpoints.Userinfo,
                OpenIddict.Abstractions.OpenIddictConstants.Permissions.GrantTypes.AuthorizationCode,
                OpenIddict.Abstractions.OpenIddictConstants.Permissions.ResponseTypes.Code,
                OpenIddict.Abstractions.OpenIddictConstants.Permissions.Scopes.Email,
                OpenIddict.Abstractions.OpenIddictConstants.Permissions.Scopes.Profile,
                "api"
            }
        };
        await manager.CreateAsync(descriptor);
    }

    var demoUser = await userManager.FindByNameAsync("alice");
    if (demoUser is null)
    {
        var user = new Infrastructure.Persistence.Identity.ApplicationUser { UserName = "alice", Email = "alice@example.com" };
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
