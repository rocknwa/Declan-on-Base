# Declan Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Declan is a decentralized platform built on Solidity that facilitates gig management between verified gig owners and freelancers. This smart contract supports account creation, gig posting, bid placement, bid acceptance with escrow handling, deadline management, reporting, and fee collection. The project also includes a comprehensive suite of automated tests using [Foundry](https://getfoundry.sh/).

---

## Table of Contents

- [Declan Contract](#declan-contract)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
  - [Architecture](#architecture)
  - [Installation \& Prerequisites](#installation--prerequisites)
  - [Usage](#usage)
    - [Compilation](#compilation)
    - [Deployment](#deployment)
    - [Interacting with the Contract](#interacting-with-the-contract)
  - [Testing](#testing)
  - [Contributing](#contributing)
  - [Contact](#contact)

---

## Overview

The Declan Contract provides a decentralized freelance marketplace that enables:

- **Gig Owners:** Create verified accounts and post new gigs.
- **Freelancers:** Register, verify their profiles, and bid on gigs.
- **Gig Management:** Escrow support, bid acceptance, deadline extension, and reporting to ensure accountability.
- **Fee Management:** Automatic fee deductions on transactions with a withdrawal function for the contract owner.

---

## Features

- **Account Management:**  
  - Gig owners can create and manage their profiles.
  - Freelancers can register, update their skills and portfolio, and get verified.
  
- **Gig Lifecycle:**  
  - Create and manage gig details including timeline, budget, and description.
  - Place and accept bids in an escrow-enabled environment to secure funds.
  - Manage gig status transitions: Open, BidPlaced, Work in Progress (WIP), Completed, Reported, and Confirmed.
  
- **Escrow & Fee Mechanism:**  
  - Secure funds in escrow during the bid acceptance phase.
  - Automatically calculate and deduct a fee percentage upon gig confirmation.
  - Withdrawal function for the contract owner to collect accumulated fees.
  
- **Deadline Management:**  
  - Extend deadlines with warning mechanism.
  - Trigger reporting which handles fund transfers based on gig status and warning count.
  
- **Testing:**  
  - Extensive test suite using Foundry ensuring correct functionality across various edge cases.

---

## Architecture

The project is structured as follows:

- **Smart Contract (`Declan.sol`):**  
  Contains the main logic for gig creation, bid management, escrow handling, freelancer verification, and more. It leverages OpenZeppelin contracts for security:
  - `Ownable`: For access control.
  - `ReentrancyGuard`: To prevent reentrant calls.
  
- **Testing Contract (`Declan.t.sol`):**  
  Provides a robust set of unit tests covering the entire gig lifecycle including edge cases and failure scenarios. It uses Foundry’s `forge-std` for simulating different actor roles and testing behaviors.

- **Mappings & Data Structures:**
  - **Freelancers:** Registered freelancer profiles.
  - **Gig Owners:** Profiles of entities that can create gigs.
  - **Gigs:** Detailed records containing gig meta-data, associated bids, and status.

---

## Installation & Prerequisites

To get started with this project, please ensure you have the following installed:


- [Foundry](https://getfoundry.sh/) for compiling, testing, and deploying Solidity contracts  
  - Install Foundry by running:
    ```bash
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    ```
- [Git](https://git-scm.com/)

Clone the repository:

```bash
git clone https://github.com/rocknwa/declan.git
cd declan
```

Install any required node dependencies if your workflow uses additional JavaScript tools:

```bash
forge install
```

---

## Usage

### Compilation

Compile the contracts using Foundry:

```bash
forge build
```

### Deployment

Deploy the contract to your desired Ethereum network (e.g., a local development network or a testnet):

```bash
forge create --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> src/Declan.sol:Declan
```

_Replace `<YOUR_RPC_URL>` and `<YOUR_PRIVATE_KEY>` with your actual RPC endpoint and key._

### Interacting with the Contract

After deploying, you can interact with the contract using:

- A [Foundry’s cast](https://book.getfoundry.sh/reference/cast) commands, or through a frontend application using [web3.js](https://web3js.readthedocs.io/) or [ethers.js](https://docs.ethers.io/).

Example using Foundry's `cast` command:

```bash
cast call <contract_address> "noOfCreatedGigs()"
```

---

## Testing

The project includes a comprehensive test suite written in Solidity using Foundry. Run the tests with:

```bash
forge test
```

Key aspects covered in tests:

- Gig creation, bid placement, and acceptance flow.
- Escrow and fee transfer validations.
- Deadline extensions and reporting scenarios.
- Account management for both freelancers and gig owners.
- Edge case handling (e.g., insufficient funds, non-verified actions).

---

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository.
2. Create a new branch for your feature or bugfix:  
   ```bash
   git checkout -b feature/YourFeatureName
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add feature: description"
   ```
4. Push to your branch:
   ```bash
   git push origin feature/YourFeatureName
   ```
5. Open a pull request.

For major changes, please open an issue first to discuss what you would like to change.


---

## Contact

For any questions or suggestions, please contact:

- **Therock Ani** – [gmail](anitherock44@gmail.com)