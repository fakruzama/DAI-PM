# DAI-PM
Patient - Ai - Blockchain
Global Decentralized AI for Personalized Medicine(DAI-PM)

This project presents a global, patient-controlled AI system for personalized medicine using blockchain and federated learning. At its core, it empowers patients to control access to their health data via smart . This project presents a global, patient-controlled AI system for personalized medicine using blockchain and federated learning. At its core, it empowers patients to control access to their health data via smart contracts, while enabling AI to learn privately across distributed sources. Each patient is assigned a hashed ID, ensuring anonymity and compliance with privacy regulations.

Healthcare institutions act as federated clients, training local models on patient data. These models apply differential privacy to protect individual records and use secure multiparty computation (MPC) to mask updates before sharing. The masked updates are aggregated off-chain, ensuring no raw data ever leaves the institution.

Blockchain smart contracts orchestrate federated learning rounds, enforce patient consent, and log record hashes. A committee of validators finalizes model artifacts using a consensus algorithm, ensuring transparency and trust. The finalized model hash is stored on-chain, while the model itself is pinned to IPFS or other decentralized storage.

This architecture combines ethical AI, privacy-preserving computation, and decentralized governance. It’s scalable across hospitals, insurers, and national health systems, enabling personalized care without compromising data sovereignty. Patients remain in control, AI remains private, and blockchain ensures integrity—making it a future-ready foundation for global healthcare transformation.
