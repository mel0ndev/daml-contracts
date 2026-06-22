const std = @import("std");
const Io = std.Io;
const Ledger = @import("./ledger.zig").Ledger;

pub fn main(init: std.process.Init) !void {
        
    const io = init.io;    
    const allocator = init.gpa;

    //set up the ledger
    var ledger = Ledger.init(allocator, io);
    defer ledger.deinit();

    const bank = try ledger.allocateParty("Bank");
    defer allocator.free(bank);
    std.debug.print("bank: {s}\n", .{bank});

    const alice = try ledger.allocateParty("Alice");
    defer allocator.free(alice);
    std.debug.print("alice: {s}\n", .{alice});
    const instrument_template = try ledger.toTemplateId("Instrument", "Instrument");
    defer allocator.free(instrument_template);

    //create the instrument "MU"
    const mu = (try ledger.create(
        instrument_template,
        .{ .issuer = bank, .symbol = "MU"},
        bank,
    )) orelse return error.CreateFailed;
    defer allocator.free(mu);
    std.debug.print("mu contract id: {s}\n", .{mu});

    const account_proposal_template = try ledger.toTemplateId("AccountProposal", "AccountProposal");
    defer allocator.free(account_proposal_template);
    
    const account_proposal = (try ledger.create(
        account_proposal_template,
        .{ .custodian = bank, .owner = alice },
        bank
    )) orelse return error.CreateFailed;
    defer allocator.free(account_proposal);
    std.debug.print("account proposal contract id: {s}\n", .{account_proposal});

    //this creates Account so that Alice can then be credited with shares
    const account = (try ledger.exercise(
        account_proposal_template,
        account_proposal,
        "Accept",
        struct {}{},
        alice
    )) orelse return error.ExerciseFailed;
    defer allocator.free(account);
    std.debug.print("account id: {s}\n", .{account});
 
    const account_template = try ledger.toTemplateId("Account", "Account");
    defer allocator.free(account_template);

    const exercise_credit = (try ledger.exercise(
        account_template,
        account,
        "Credit",
        .{ .symbol = "MU", .amount = "100.0" },
        bank
    )) orelse return error.ExerciseFailed;   
    defer allocator.free(exercise_credit);

    const bal = try ledger.balanceOf(alice, "MU");
    std.debug.print("MU balance: {d}\n", .{bal});
}
