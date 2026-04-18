-- ==========================================
-- 兼容所有 Wireshark 版本的 ZooKeeper 协议解析器
-- 修复了越界问题，带边界检查
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
-- 工具函数：安全读取（带边界检查）
-- ==============================
local function tvb_safe_read(tvb, offset, len)
    if offset + len > tvb:len() then
        return nil
    end
    return tvb(offset, len)
end

-- ==============================
-- 解析：ZK Client (2181 类)
-- ==============================
function zk_client.dissector(tvb, pinfo, tree)
    pinfo.cols.protocol = "ZK"
    if tvb:len() < 4 then return end

    local len_buf = tvb_safe_read(tvb, 0, 4)
    if not len_buf then return end
    local len = len_buf:uint()

    local t = tree:add(zk_client, tvb(), "ZooKeeper Client")
    t:add(f_zk_len, len_buf)

    if len < 8 or tvb:len() < len + 4 then return end

    local offset = 4
    local xid_buf = tvb_safe_read(tvb, offset, 4)
    if not xid_buf then return end
    t:add(f_zk_xid, xid_buf)
    offset = offset + 4

    local op_buf = tvb_safe_read(tvb, offset, 4)
    if not op_buf then return end
    local op = op_buf:uint()
    local opname = op_names[op] or tostring(op)
    t:add(f_zk_op, op_buf):append_text(" ("..opname..")")
    pinfo.cols.info = "ZK "..opname
    offset = offset + 4

    if (op == 1 or op == 2 or op == 3 or op == 4 or op == 5) then
        local plen_buf = tvb_safe_read(tvb, offset, 4)
        if not plen_buf then return end
        local plen = plen_buf:uint()
        offset = offset + 4
        if plen > 0 then
            local path_buf = tvb_safe_read(tvb, offset, plen)
            if path_buf then
                local path = path_buf:string()
                t:add(f_zk_path, path_buf, path)
            end
        end
    end
end

-- ==============================
-- 解析：ZAB Peer (2888 类)
-- ==============================
function zab_peer.dissector(tvb, pinfo, tree)
    pinfo.cols.protocol = "ZAB"
    if tvb:len() < 1 then return end

    local t = tree:add(zab_peer, tvb(), "ZAB Peer")
    local type_buf = tvb_safe_read(tvb, 0, 1)
    if not type_buf then return end
    local typ = type_buf:uint()
    local name = zab_type[typ] or tostring(typ)
    t:add(f_zab_type, type_buf):append_text(" ("..name..")")
    pinfo.cols.info = "ZAB "..name
end

-- ==============================
-- 解析：Election (3888 类) —— 修复越界
-- ==============================
function zab_elect.dissector(tvb, pinfo, tree)
    pinfo.cols.protocol = "ELECTION"
    if tvb:len() < 40 then return end -- 至少需要40字节

    local t = tree:add(zab_elect, tvb(), "ZAB Election")
    local offset = 0

    -- 版本
    local ver_buf = tvb_safe_read(tvb, offset, 4)
    if not ver_buf then return end
    local ver = ver_buf:int()
    t:add(f_ele_ver, ver_buf)
    offset = offset + 4

    -- SID
    local sid_buf = tvb_safe_read(tvb, offset, 8)
    if not sid_buf then return end
    local sid = sid_buf:uint64()
    t:add(f_ele_sid, sid_buf)
    offset = offset + 8

    -- Leader
    local leader_buf = tvb_safe_read(tvb, offset, 8)
    if not leader_buf then return end
    local leader = leader_buf:uint64()
    t:add(f_ele_lead, leader_buf)
    offset = offset + 8

    -- ZXID
    local zxid_buf = tvb_safe_read(tvb, offset, 8)
    if not zxid_buf then return end
    local zxid = zxid_buf:uint64()
    t:add(f_ele_zxid, zxid_buf)
    offset = offset + 8

    -- Epoch
    local epoch_buf = tvb_safe_read(tvb, offset, 4)
    if not epoch_buf then return end
    local epoch = epoch_buf:uint()
    t:add(f_ele_epoch, epoch_buf)
    offset = offset + 4

    -- State
    local state_buf = tvb_safe_read(tvb, offset, 4)
    if not state_buf then return end
    local state = state_buf:uint()
    local sname = state_names[state] or tostring(state)
    t:add(f_ele_state, state_buf):append_text(" ("..sname..")")

    pinfo.cols.info = "ELECTION sid:"..sid.." vote:"..leader.." "..sname
end

-- ==============================
-- 绑定默认端口
-- ==============================
local tcp_table = DissectorTable.get("tcp.port")
tcp_table:add(2181, zk_client)
tcp_table:add(2888, zab_peer)
tcp_table:add(3888, zab_elect)