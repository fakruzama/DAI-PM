import express from "express";
import dotenv from "dotenv";
import axios from "axios";
import { ethers } from "ethers";

dotenv.config();

const RPC_URL = process.env.RPC_URL;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const MPC_URL = process.env.MPC_URL;
const PORT = Number(process.env.PORT || 8080);

const ABI = [
  "function consent(bytes32,bytes32) view returns (bool,uint256,string)",
  "function latestRoundIndex(bytes32) view returns (uint256)",
  "function getRound(bytes32,uint256) view returns (tuple(bytes32 taskId,uint256 roundIndex,uint256 startAt,uint256 endAt,uint256 maxParticipants,uint256 epsilon,uint256 delta,bool closed,bytes32 modelHash))",
  "function commitUpdate(bytes32,uint256,bytes32) external"
];

const provider = new ethers.JsonRpcProvider(RPC_URL);
const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);

const app = express();
app.use(express.json());

// Check consent and provide current round config
app.post("/fl/config", async (req, res) => {
  try {
    const { patientIdHex, taskIdHex } = req.body;
    const consentData = await contract.consent(patientIdHex, taskIdHex);
    const allowed = consentData[0];
    if (!allowed) return res.status(403).json({ error: "Consent not granted" });
    const idx = await contract.latestRoundIndex(taskIdHex);
    const round = await contract.getRound(taskIdHex, idx);
    return res.json({
      taskId: taskIdHex,
      roundIndex: Number(round.roundIndex),
      epsilon: Number(round.epsilon),
      delta: Number(round.delta),
      maxParticipants: Number(round.maxParticipants),
      closed: round.closed
    });
  } catch (e) {
    return res.status(500).json({ error: "config failed" });
  }
});

// Submit masked update to MPC
app.post("/fl/submit", async (req, res) => {
  try {
    const { taskIdHex, roundIndex, clientId, commitHash, maskedUpdate } = req.body;
    const resp = await axios.post(`${MPC_URL}/secure_agg/submit`, {
      taskIdHex, roundIndex, clientId, commitHash, maskedUpdate
    });
    return res.json(resp.data);
  } catch (e) {
    return res.status(500).json({ error: "submit failed" });
  }
});

// Get aggregated result
app.get("/fl/aggregate", async (req, res) => {
  try {
    const { taskIdHex, roundIndex } = req.query;
    const resp = await axios.get(`${MPC_URL}/secure_agg/result`, { params: { taskIdHex, roundIndex } });
    return res.json(resp.data);
  } catch (e) {
    return res.status(500).json({ error: "aggregate failed" });
  }
});

app.listen(PORT, () => console.log(`[API] Gateway listening on ${PORT}`));
