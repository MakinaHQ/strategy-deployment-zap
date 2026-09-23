# Safe Transaction Builder batches

JSON files importable in the Safe Transaction Builder app (Apps → Transaction Builder → upload). Each file targets one
Safe on one chain; `meta.description` carries the per-transaction notes and every entry includes both the decoded
`contractInputsValues` and the raw `data` so signers can compare against what the Safe UI shows.

| File                                   | Safe                           | Purpose                                                                                     |
| -------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------- |
| `Base-xStocks-oracle-feed-routes.json` | DAO safe `0x62244C74…` on Base | `setFeedRoute` on the OracleRegistry for the 7 xStocks accounting tokens (mirrors nonce 67) |

Regenerate a batch by editing the values and recomputing `data` with
`cast calldata "setFeedRoute(address,address,uint256,address,uint256)" <token> <feed1> <staleness1> <feed2> <staleness2>`.
