# Privacy-Preserving Bounty Judge — Commit-Reveal System

## Problem
Submissions public thi — koi bhi doosre ka answer copy karke better version submit kar sakta tha.

## Solution: Commit-Reveal Flow
1. **Commit Phase** → Sirf hash submit karo (answer hidden)
2. **Reveal Phase** → Deadline ke baad actual answer reveal karo
3. **AI Judging** → Saare revealed answers batch mein judge hote hain
4. **Finalize** → Winner ko reward milta hai

## Lifecycle
submitCommitment() → revealAnswer() → judgeAll() → finalizeWinner()

## What is Public vs Hidden
| Data | Status |
|------|--------|
| Commitment hash | Public |
| Plaintext answer (before reveal) | Hidden |
| Plaintext answer (after reveal) | Public |
| Salt | Hidden (participant ke paas) |

## Architecture
- **On-chain:** commitment hash, reward, deadlines, revealed answers
- **Off-chain:** plaintext answer (reveal tak), salt, AI oracle

## Hash Formula
keccak256(answer + salt + msg.sender + bountyId)

## Reflection
Bounty system mein question, reward, deadlines, aur commitment hashes public honi chahiye taaki trust establish ho. Plaintext answers judging complete hone tak hidden rehne chahiye — copying rokne ke liye. Salt values bhi private rehni chahiye. AI ke liye suitable hai objective comparative evaluation aur batch ranking. Human judgment zaruuri hai edge cases, disputes, aur ethical decisions mein — creator ko final veto power rehna chahiye.
