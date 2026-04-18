local zk_client = Proto("zk_client", "ZooKeeper Client")

local op_names = {
    [0]  = "CONNECT",
    [1]  = "CREATE",
    [2]  = "DELETE",
    [3]  = "EXISTS",
    [4]  = "GET_DATA",
    [5]  = "SET_DATA",
    [6]  = "GET_CHILDREN",
    [7]  = "SYNC",
    [13] = "SET_WATCHES",
    [14] = "PING",
    [15] = "GET_CHILDREN2",
    [16] = "CHECK",
    [17] = "MULTI",
    [19] = "AUTH",
    [25] = "WATCH_EVENT"
}

local f_len   = ProtoField.uint32("zk.len", "Length")
local f_xid   = ProtoField.int32("zk.xid", "Xid")
local f_op    = ProtoField.uint32("zk.op", "Opcode")
local f_path  = ProtoField.string("zk.path", "Path")
local f_data  = ProtoField.bytes("zk.data", "Data")
local f_ver   = ProtoField.int32("zk.version", "Version")

zk_client.fields = { f_len, f_xid, f_op, f_path, f_data, f_ver }

local function dissect_client(tvb, pinfo, tree)
    pinfo.cols.protocol = "ZK_CLIENT"
    local total_len = tvb:len()
    if total_len < 8 then return end

    local t = tree:add(zk_client, tvb(), "ZooKeeper Client")
    t:add(f_len, tvb(0,4))
    local offset = 4

    t:add(f_xid, tvb(offset,4))
    offset = offset + 4

    local op = tvb(offset,4):uint()
    local opname = op_names[op] or tostring(op)
    t:add(f_op, tvb(offset,4)):append_text(" ("..opname..")")
    offset = offset + 4

    pinfo.cols.info = "ZK "..opname

    if op == 1 or op ==2 or op ==3 or op ==4 or op ==5 then
        if offset + 4 > total_len then return end
        local plen = tvb(offset,4):uint()
        offset = offset + 4
        if plen > 0 and offset + plen <= total_len then
            t:add(f_path, tvb(offset, plen), tvb(offset, plen):string())
            offset = offset + plen
        end
    end

    if op == 5 then
        if offset + 4 > total_len then return end
        t:add(f_ver, tvb(offset,4))
        offset = offset + 4

        if offset + 4 > total_len then return end
        local dlen = tvb(offset,4):uint()
        offset = offset + 4

        if dlen > 0 and offset + dlen <= total_len then
            t:add(f_data, tvb(offset, dlen))
        end
    end
end

function zk_client.dissector(tvb, pinfo, tree)
    dissect_client(tvb, pinfo, tree)
end

local dt = DissectorTable.get("tcp.port")
dt:add(2181, zk_client)
dt:add(3181, zk_client)
dt:add(4181, zk_client)
dt:add(5181, zk_client)