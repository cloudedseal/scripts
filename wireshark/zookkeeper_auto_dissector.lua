-- ==========================================
-- 兼容所有 Wireshark 版本的 ZooKeeper 协议解析器
-- 支持：客户端(2181)、ZAB同步(2888)、选举(3888)
-- ==========================================

local zk_client = Proto("zk_client", "ZooKeeper Client Protocol")
local zab_peer  = Proto("zab_peer",  "ZAB Peer Protocol")
local zab_elect = Proto("zab_elect","ZAB Leader Election")

-- ==============================
-- ZK Client Opcode
-- ==============================
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
    [19] = "AUTH",
    [25] = "WATCH_EVENT"
}

-- ==============================
-- ZAB Peer Type
-- ==============================
local zab_type = {
    [1] = "PROPOSAL",
    [2] = "ACK",
    [3] = "COMMIT",
    [4] = "PING",
    [5] = "REVALIDATE",
    [6] = "SYNC",
    [7] = "NEWLEADER",
    [8] = "UPTODATE"
}

-- ==============================
-- Election State
-- ==============================
local state_names = {
    [0] = "LOOKING",
    [1] = "FOLLOWING",
    [2] = "LEADING",
    [3] = "OBSERVING"
}

-- ==============================
-- Fields
-- ==============================
local f_zk_len   = ProtoField.uint32("zk.len", "Length")
local f_zk_xid   = ProtoField.int32("zk.xid", "Xid")
local f_zk_op    = ProtoField.uint32("zk.op", "Opcode")
local f_zk_path  = ProtoField.string("zk.path", "Path")
local f_zk_data  = ProtoField.bytes("zk.data", "Data")

local f_zab_type = ProtoField.uint8("zab.type", "Type")
local f_zab_zxid = ProtoField.uint64("zab.zxid", "ZXID", base.HEX)

local f_ele_ver  = ProtoField.int32("elect.ver", "Version")
local f_ele_sid  = ProtoField.uint64("elect.sid", "SID")
local f_ele_lead = ProtoField.uint64("elect.leader", "VotedLeader")
local f_ele_zxid = ProtoField.uint64("elect.zxid", "ZXID", base.HEX)
local f_ele_epoch= ProtoField.uint32("elect.epoch", "Epoch")
local f_ele_state= ProtoField.uint32("elect.state", "State")

zk_client.fields = { f_zk_len, f_zk_xid, f_zk_op, f_zk_path, f_zk_data }
zab_peer.fields  = { f_zab_type, f_zab_zxid }
zab_elect.fields = { f_ele_ver, f_ele_sid, f_ele_lead, f_ele_zxid, f_ele_epoch, f_ele_state }

-- ==============================
-- 解析：ZK Client (2181 类)
-- ==============================
function zk_client.dissector(tvb, pinfo, tree)
    pinfo.cols.protocol = "ZK"
    local len = tvb(0,4):uint()
    local t = tree:add(zk_client, tvb(), "ZooKeeper Client")
    t:add(f_zk_len, tvb(0,4))

    if len < 8 then return end
    local offset = 4
    local xid = tvb(offset,4):int()
    t:add(f_zk_xid, tvb(offset,4))
    offset = offset +4

    local op = tvb(offset,4):uint()
    local opname = op_names[op] or tostring(op)
    t:add(f_zk_op, tvb(offset,4)):append_text(" ("..opname..")")
    pinfo.cols.info = "ZK "..opname
    offset = offset +4

    if op == 1 or op == 2 or op == 3 or op == 4 or op == 5 then
        local plen = tvb(offset,4):uint()
        offset = offset +4
        if plen > 0 then
            local path = tvb(offset, plen):string()
            t:add(f_zk_path, tvb(offset-plen, plen+4), path)
        end
    end
end

-- ==============================
-- 解析：ZAB Peer (2888 类)
-- ==============================
function zab_peer.dissector(tvb, pinfo, tree)
    pinfo.cols.protocol = "ZAB"
    local t = tree:add(zab_peer, tvb(), "ZAB Peer")
    local typ = tvb(0,1):uint()
    local name = zab_type[typ] or tostring(typ)
    t:add(f_zab_type, tvb(0,1)):append_text(" ("..name..")")
    pinfo.cols.info = "ZAB "..name
end

-- ==============================
-- 解析：Election (3888 类)
-- ==============================
function zab_elect.dissector(tvb, pinfo, tree)
    pinfo.cols.protocol = "ELECTION"
    local t = tree:add(zab_elect, tvb(), "ZAB Election")
    local offset = 0

    local ver = tvb(offset,4):int() offset = offset+4
    t:add(f_ele_ver, tvb(offset-4,4))

    local sid = tvb(offset,8):uint64() offset = offset+8
    t:add(f_ele_sid, tvb(offset-8,8))

    local leader = tvb(offset,8):uint64() offset = offset+8
    t:add(f_ele_lead, tvb(offset-8,8))

    local zxid = tvb(offset,8):uint64() offset = offset+8
    t:add(f_ele_zxid, tvb(offset-8,8))

    local epoch = tvb(offset,4):uint() offset = offset+4
    t:add(f_ele_epoch, tvb(offset-4,4))

    local state = tvb(offset,4):uint() offset = offset+4
    local sname = state_names[state] or tostring(state)
    t:add(f_ele_state, tvb(offset-4,4)):append_text(" ("..sname..")")

    pinfo.cols.info = "ELECTION sid:"..sid.." vote:"..leader.." "..sname
end

-- ==============================
-- 绑定默认端口（兼容旧版 Wireshark）
-- ==============================
local tcp_table = DissectorTable.get("tcp.port")
tcp_table:add(2181, zk_client)
tcp_table:add(2888, zab_peer)
tcp_table:add(3888, zab_elect)