using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xpact.Api;
using Xpact.Api.Workers;

namespace Xpact.Api.Tests;

/// <summary>#357: uploads are refused before their body is read, per visitor and against a memory budget.</summary>
public class UploadGateTests
{
    private static UploadGate Gate(int perClient = 2, int budgetMb = 10) =>
        new(Options.Create(new XpactOptions { MaxWorkersPerClient = perClient, MaxBufferedMb = budgetMb }),
            NullLogger<UploadGate>.Instance);

    [Fact]
    public void A_visitor_gets_at_most_MaxWorkersPerClient_uploads_in_flight()
    {
        var gate = Gate(perClient: 2);
        Assert.True(gate.TryEnter("a", 1, out var first, out _));
        Assert.True(gate.TryEnter("a", 1, out var second, out _));
        Assert.False(gate.TryEnter("a", 1, out _, out int status));
        Assert.Equal(StatusCodes.Status429TooManyRequests, status);
        Assert.True(gate.TryEnter("b", 1, out var other, out _)); // another visitor is not affected

        first!.Dispose();
        Assert.True(gate.TryEnter("a", 1, out var third, out _)); // a finished upload frees its place
        second!.Dispose(); third!.Dispose(); other!.Dispose();
        Assert.Equal(0, gate.BufferedBytes);
    }

    [Fact]
    public void The_memory_budget_refuses_with_503_and_is_freed_again()
    {
        var gate = Gate(perClient: 100, budgetMb: 10);
        long mb = 1024 * 1024;
        Assert.True(gate.TryEnter("a", 6 * mb, out var big, out _));
        Assert.False(gate.TryEnter("b", 6 * mb, out _, out int status));
        Assert.Equal(StatusCodes.Status503ServiceUnavailable, status);
        Assert.True(gate.TryEnter("c", 4 * mb, out var small, out _)); // what still fits is admitted
        big!.Dispose();
        Assert.True(gate.TryEnter("b", 6 * mb, out var again, out _));
        small!.Dispose(); again!.Dispose();
        Assert.Equal(0, gate.BufferedBytes);
    }

    [Fact]
    public void One_upload_larger_than_the_budget_still_runs_when_nothing_else_does()
    {
        var gate = Gate(budgetMb: 1);
        Assert.True(gate.TryEnter("a", 50L * 1024 * 1024, out var lease, out _));
        lease!.Dispose();
        lease.Dispose(); // a second Dispose must not free the reservation twice
        Assert.Equal(0, gate.BufferedBytes);
    }

    [Fact]
    public void The_estimate_uses_the_largest_body_when_the_length_is_unknown()
    {
        var gate = Gate();
        Assert.Equal(400, UploadGate.Estimate(100, 1000));
        Assert.Equal(4000, UploadGate.Estimate(null, 1000));
        Assert.Equal(4000, UploadGate.Estimate(5000, 1000));
    }
}
