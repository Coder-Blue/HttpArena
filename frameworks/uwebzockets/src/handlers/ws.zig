const uz = @import("uWebZockets");

pub const PATH = "/ws";

pub fn onMessage(socket: *uz.WebSocket, message: []const u8, opcode: uz.Opcode) void {
    socket.send(message, opcode) catch {};
}
