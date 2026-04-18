
local zab_elect = Proto("zab_elect", "ZK_ELECTION")

local state_names = {
    [0] = "LOOKING",
    [1] = "FOLLOWING",
    [2] = "LEADING",
    [3] = "OBSERVING"
}

local f_ver         = ProtoField.uint32("elect.ver", "Version")
local f_sid         = ProtoField.uint64("elect.sid", "MySid")        -- 自己的ID
local f_zxid        = ProtoField.uint64("elect.zxid", "ZXID")
local f_leader      = ProtoField.uint64("elect.votedLeader", "VotedLeader") -- 投给谁
local f_ele_epoch   = ProtoField.uint32("elect.electionEpoch", "ElectionEpoch")
local f_peer_epoch  = ProtoField.uint32("elect.peerEpoch", "PeerEpoch")
local f_state       = ProtoField.uint32("elect.state", "State")

zab_elect.fields = {
    f_ver, f_sid, f_zxid, f_leader,
    f_ele_epoch, f_peer_epoch, f_state
}

function zab_elect.dissector(tvb, pinfo, tree)
    pinfo.cols.protocol:set("ZK_ELECTION")
    
    local pkt_len = tvb:len()
    if pkt_len < 44 then
        return
    end

    local t = tree:add(zab_elect, tvb(), "ZooKeeper 3.9.5 Leader Election")
    local offset = 0

    -- 1) version (4)  offset:0
    t:add(f_ver, tvb(offset,4))
    offset = offset + 4

    -- 2) my sid (8)  offset:4 ✅ 正确位置
    local my_sid = tvb(offset,8):uint64()
    t:add(f_sid, tvb(offset,8))
    offset = offset + 8

    -- 3) zxid (8)  offset:12
    t:add(f_zxid, tvb(offset,8))
    offset = offset + 8

    -- 4) votedLeader (8)  offset:20 ✅ 正确位置
    local voted_leader = tvb(offset,8):uint64()
    t:add(f_leader, tvb(offset,8))
    offset = offset + 8

    -- 5) electionEpoch (4) offset:28
    t:add(f_ele_epoch, tvb(offset,4))
    offset = offset + 4

    -- 6) peerEpoch (4) offset:32
    t:add(f_peer_epoch, tvb(offset,4))
    offset = offset + 4

    -- 7) state (4) offset:36
    local state_val = tvb(offset,4):uint()
    local state_str = state_names[state_val] or "UNKNOWN"
    t:add(f_state, tvb(offset,4)):append_text(" ("..state_str..")")

    pinfo.cols.info:set("SID:" .. my_sid .. " VOTE:" .. voted_leader .. " " .. state_str)
end

-- 注册你的端口
local tcp = DissectorTable.get("tcp.port")
tcp:add(10001, zab_elect)
tcp:add(20001, zab_elect)
tcp:add(30001, zab_elect)