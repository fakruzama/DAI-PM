# Patient-controlled AI + blockchain federated system

This repo provides a runnable scaffold:
- Solidity smart contract for patient consent and FL round coordination.
- API Gateway to enforce consent and orchestrate federated learning.
- MPC service for secure aggregation (toy).
- Federated client for local DP + masking.
- Committee coordinator for round finalization.

## Prerequisites
- Node.js 18+
- Python 3.10+
- A deployed PatientFLRegistry contract (or adapt to your deployment)

## Quickstart

1. Install API Gateway:
   ```bash
   cd api-gateway
   cp .env.example .env
   npm install
   npm start

2. Install MPC service:

cd ../mpc
cp .env.example .env
npm install
npm start

3. Run federated client:
   cd ../client
pip install -r requirements.txt
python federated_client.py

4. Run committee coordinator:
   cd ../coordinator
cp .env.example .env
npm install
npm start

