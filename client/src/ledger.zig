//contains all of our routes and api requests + handlers
//create our structs, etc
const std = @import("std");

const user_id = "ledger-api-user";

const wildcard = .{
    .verbose = false,
    .filtersForAnyParty = .{
        .cumulative = .{
            .{ .identifierFilter = .{ .WildcardFilter = .{ .value = .{ .includeCreatedEventBlob = false } } } },
        },
    },
};

const LedgerEnd = struct { offset: i64 };

const PartyResponse = struct {
    partyDetails: struct { party: []const u8 },
};

const CreatedEvent = struct {
    contractId: []const u8,
    templateId: []const u8,
};

const Event = struct {
    CreatedEvent: ?CreatedEvent = null,
};

const TxResponse = struct {
    transaction: struct {
        events: []Event,
    },
};

// one entry of the /v2/state/active-contracts response (a top-level array)
const Acs = struct {
    contractEntry: struct {
        JsActiveContract: ?struct {
            createdEvent: struct {
                templateId: []const u8,
                createArgument: std.json.Value,
            },
        } = null,
    },
};


pub const Ledger = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    client: std.http.Client,
    base_url: []const u8 = "http://localhost:6864",
 
    pub fn init(allocator: std.mem.Allocator, io: std.Io) Ledger {
        return .{
            .allocator = allocator, 
            .io = io,
            .client = std.http.Client{.allocator = allocator, .io = io},
        };
    }

    pub fn deinit(self: *Ledger) void {
        self.client.deinit();
    }
    
    //get
    pub fn get(self: *Ledger, url: []const u8) ![]const u8 {
        var body: std.Io.Writer.Allocating = .init(self.allocator); 
        defer body.deinit();

        var buf: [256]u8 = undefined;  
        const full_url = try std.fmt.bufPrint(&buf, "{s}{s}", .{self.base_url, url});

        const result = try self.client.fetch(.{
            .location = .{ .url = full_url },
            .response_writer = &body.writer,
        });
        _ = result; //handle the error  
        
        var list = body.toArrayList(); 
        return try list.toOwnedSlice(self.allocator);
    }

    pub fn post(self: *Ledger, url: []const u8, payload: ?[]const u8) ![]const u8 {
        var body: std.Io.Writer.Allocating = .init(self.allocator); 
        defer body.deinit();

        var buf: [256]u8 = undefined;  
        const full_url = try std.fmt.bufPrint(&buf, "{s}{s}", .{self.base_url, url});

        const result = try self.client.fetch(.{
            .location = .{ .url = full_url },
            .method = .POST,
            .payload = payload,
            .headers = .{ .content_type = .{ .override = "application/json" } },
            .extra_headers = &.{
                .{ .name = "Authorization", .value = "Bearer alice" },
            },
            .response_writer = &body.writer,
        });
        _ = result; //TODO handle the error

        var list = body.toArrayList(); 
        return try list.toOwnedSlice(self.allocator);
    }

    pub fn allocateParty(self: *Ledger, party: []const u8) ![]const u8 {
        const payload = try std.json.Stringify.valueAlloc(self.allocator, .{
            .partyIdHint = party, .identityProviderId = "",
        }, .{});
        defer self.allocator.free(payload);
        
        const res = try self.post("/v2/parties", payload);
        defer self.allocator.free(res);

        const parsed = try std.json.parseFromSlice(PartyResponse, self.allocator, res, .{.ignore_unknown_fields = true});
        defer parsed.deinit();
            
        //caller is responsible for freeing this slice!    
        return try self.allocator.dupe(u8, parsed.value.partyDetails.party);
    }

    pub fn create(self: *Ledger, template_id: []const u8, args: anytype, act_as: []const u8) !?[]const u8 {
        const stamp = std.Io.Clock.real.now(self.io).toMilliseconds(); 
        const command_id = try std.fmt.allocPrint(self.allocator, "create-{d}", .{stamp});
        defer self.allocator.free(command_id);

        const payload = try std.json.Stringify.valueAlloc(self.allocator, 
            .{
                .commands = .{
                    .commands = .{
                        .{ .CreateCommand = .{
                            .templateId = template_id, 
                            .createArguments = args,
                        } },
                    },
                    .commandId = command_id,
                    .actAs = .{act_as},
                    .userId = user_id,
                },
                .transactionFormater = .{
                    .transactionShape = "TRANSACTION_SHAPE_ACS_DELTA",
                    .eventFormat = wildcard
                },
        }, .{});
        defer self.allocator.free(payload);
        
        const res = try self.post("/v2/commands/submit-and-wait-for-transaction", payload);
        defer self.allocator.free(res);

        const parsed = try std.json.parseFromSlice(TxResponse, self.allocator, res, .{.ignore_unknown_fields = true});
        defer parsed.deinit(); 
       
        var contract_id: ?[]const u8 = null;
        const events = parsed.value.transaction.events;  
        for (events) |event| {
            if (event.CreatedEvent == null) continue;
            contract_id = event.CreatedEvent.?.contractId;
            break; //there should only be one, but break for readability
        }

        if (contract_id != null) {
            //caller must free! 
            const dupe = try self.allocator.dupe(u8, contract_id.?); 
            return dupe;
        } else {
            return null;
        }
    }

    pub fn exercise(
        self: *Ledger, 
        template_id: []const u8,
        contract_id: []const u8,
        choice: []const u8,
        args: anytype,
        act_as: []const u8
    ) !?[]const u8 {
        const stamp = std.Io.Clock.real.now(self.io).toMilliseconds(); 
        const command_id = try std.fmt.allocPrint(self.allocator, "create-{d}", .{stamp});
        defer self.allocator.free(command_id);

        const payload = try std.json.Stringify.valueAlloc(self.allocator, 
            .{
                .commands = .{
                    .commands = .{
                        .{ .ExerciseCommand = .{
                            .templateId = template_id, 
                            .contractId = contract_id,
                            .choice = choice,
                            .choiceArgument = args,
                        } },
                    },
                    .commandId = command_id,
                    .actAs = .{act_as},
                    .userId = user_id,
                },
                .transactionFormater = .{
                    .transactionShape = "TRANSACTION_SHAPE_ACS_DELTA",
                    .eventFormat = wildcard
                },
        }, .{});
        defer self.allocator.free(payload);

        const res = try self.post("/v2/commands/submit-and-wait-for-transaction", payload);
        defer self.allocator.free(res);
        
        const parsed = try std.json.parseFromSlice(TxResponse, self.allocator, res, .{.ignore_unknown_fields = true});
        defer parsed.deinit(); 
        
        var created_id: ?[]const u8 = null;
        const events = parsed.value.transaction.events;  
        for (events) |event| {
            if (event.CreatedEvent == null) continue;
            created_id = event.CreatedEvent.?.contractId;
            break; //there should only be one, but break for readability
        }
        
        if (created_id != null) {
            //caller must free! 
            const dupe = try self.allocator.dupe(u8, created_id.?); 
            return dupe;
        } else {
            return null;
        }
    }

    pub fn ledgerEnd(self: *Ledger) !i64 {
        const res = try self.get("/v2/state/ledger-end");
        defer self.allocator.free(res);

        const parsed = try std.json.parseFromSlice(LedgerEnd, self.allocator, res, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        return parsed.value.offset;
    }

    pub fn balanceOf(self: *Ledger, party: []const u8, symbol: []const u8) !f32 {
        //get the ledger end so we can pass it as the offset
        var end_future = self.io.async(Ledger.ledgerEnd, .{ self });
        const offset = try end_future.await(self.io);

        const party_filter = .{
            .cumulative = .{
                .{ .identifierFilter = .{ .WildcardFilter = .{ .value = .{ .includeCreatedEventBlob = false } } } },
            },
        };
        const pf_json = try std.json.Stringify.valueAlloc(self.allocator, party_filter, .{});
        defer self.allocator.free(pf_json);

        // filtersByParty is keyed by the party id (a runtime key), so build the
        // body with allocPrint, injecting the party key and the offset.
        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"filter":{{"filtersByParty":{{"{s}":{s}}}}},"verbose":false,"activeAtOffset":{d}}}
        , .{ party, pf_json, offset });
        defer self.allocator.free(payload);

        const res = try self.post("/v2/state/active-contracts", payload);
        defer self.allocator.free(res);

        const parsed = try std.json.parseFromSlice([]Acs, self.allocator, res, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        return sumHoldings(parsed.value, symbol);
    }

    pub fn toTemplateId(self: *Ledger, module: []const u8, template: []const u8) ![]const u8 {
        const fmt = try std.fmt.allocPrint(self.allocator, "#NasdaqDemo:{s}:{s}", .{module, template});
        return fmt;
    }
};

// sum the amounts of all Holding contracts matching `symbol` in an active-contracts set
fn sumHoldings(entries: []const Acs, symbol: []const u8) !f32 {
    var total: f32 = 0;
    for (entries) |entry| {
        const active = entry.contractEntry.JsActiveContract orelse continue;
        if (!std.mem.endsWith(u8, active.createdEvent.templateId, ":Holding:Holding")) continue;

        // Holding args are { owner, symbol, amount } — symbol & amount are strings
        const arg = active.createdEvent.createArgument.object;
        if (!std.mem.eql(u8, arg.get("symbol").?.string, symbol)) continue;
        total += try std.fmt.parseFloat(f32, arg.get("amount").?.string);
    }
    return total;
}
