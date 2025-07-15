# 🔮 OracleVault

## Decentralized Prediction Market Platform on Stacks

OracleVault is a revolutionary prediction market platform built on the Stacks blockchain, enabling users to create prophecy markets, stake predictions, and earn rewards based on accurate forecasts.

## 🌟 Features

### Core Functionality
- **Prophecy Creation**: Any user can create prediction markets with custom visions and deadlines
- **Stake Placement**: Users can stake STX tokens on their predictions (true/false outcomes)
- **Automated Rewards**: Winners automatically receive proportional rewards from the losing side's treasury
- **Emergency Controls**: Guardian-managed emergency halt system for security

### Key Components
- **Prophecies**: Prediction markets with descriptions, deadlines, and outcomes
- **Stakes**: User bets on specific prophecy outcomes
- **Vaults**: Separate treasuries for true/false predictions
- **Oracle System**: Market creators act as oracles to resolve outcomes

## 📊 Contract Architecture

### Data Structures
- `prophecies`: Core market data (oracle, vision, revelation, sealed status, deadline)
- `stakes`: User prediction data (wager amount, prediction choice)
- `prediction-vaults`: Separate treasuries for true/false outcomes

### Key Constants
- **Oracle Tax**: 100 microSTX platform fee per stake
- **Minimum Stake**: 1,000 microSTX (0.001 STX)
- **Maximum Stake**: 1,000,000,000 microSTX (1,000 STX)
- **Deadline Range**: 100 to 52,560 blocks (≈1 year maximum)

## 🚀 Usage

### Creating a Prophecy Market
```clarity
(create-prophecy "Will BTC reach $100k by end of 2024?" u52560)
```

### Placing a Stake
```clarity
(place-stake u1 true u10000) ;; Stake 0.01 STX on "true" for prophecy #1
```

### Sealing a Prophecy (Oracle Only)
```clarity
(seal-prophecy u1 true) ;; Resolve prophecy #1 as "true"
```

### Claiming Rewards
```clarity
(claim-rewards u1) ;; Claim winnings from prophecy #1
```

### Emergency Refunds
```clarity
(refund-stake u1) ;; Refund stake if prophecy expired unresolved
```

## 🔒 Security Features

### Access Control
- **Guardian System**: Contract owner can halt operations during emergencies
- **Oracle Authority**: Only prophecy creators can resolve their markets
- **Validation**: Comprehensive input validation and error handling

### Error Handling
- 13 distinct error codes for different failure scenarios
- Robust validation for all user inputs
- Protection against common attack vectors

## 📈 Economic Model

### Fee Structure
- **Oracle Tax**: 100 microSTX per stake placement
- **Winner Takes All**: Proportional distribution based on stake size
- **No Additional Fees**: Simple, transparent fee structure

### Reward Calculation
Winners receive rewards proportional to their stake size relative to the total winning side treasury. The reward formula ensures fair distribution while maintaining economic incentives.

## 🛠️ Development

### Prerequisites
- Stacks blockchain development environment
- Clarity language knowledge
- STX tokens for testing

### Testing
The contract includes comprehensive validation and error handling. Test all functions thoroughly in a development environment before mainnet deployment.

### Deployment
Deploy to Stacks testnet first, then mainnet after thorough testing and security review.

## 🎯 Use Cases

- **Sports Betting**: Predict game outcomes, tournament winners
- **Financial Markets**: Forecast price movements, market events
- **Politics**: Election outcomes, policy decisions
- **Entertainment**: Award show winners, box office predictions
- **General Events**: Weather, social trends, technology adoption

## 🔮 Future Enhancements

- Multi-outcome markets (beyond binary true/false)
- Automated market makers (AMM) for continuous trading
- Reputation systems for oracle quality
- Time-weighted rewards for early predictors
- Integration with external data feeds

## 📄 License

This project is open source. Please review the license file for specific terms and conditions.

## 🤝 Contributing

Contributions are welcome! Please follow the contribution guidelines and ensure all code is thoroughly tested.

