# Savings GYD (sGYD)

## Overview

The main idea of sGYD is to create a mechanism where users can deposit GYD into an sGYD contract to earn a share of the yield earned by assets in the GYD reserve on L1.

Yield is to be shared in the following venues:

1. Users who stake GYD in the sGYD contract (both on L1 and L2)
2. Users who LP in certain GYD/XXX E-CLPs (both on L1 and L2)

Yield is paid in freshly-minted GYD.

## High level components

There are the following components:

* An off-chain script computes, across a given time frame (1) the yield of the reserve per GYD and time unit and (2) contributions of different venues (sGYD, pools). It then computes the amounts to be emitted.
* A Manager Contract that takes in the output from the off-chain script, mints new GYD, and distributes them to venues according to the data. The calls to the manager contract are made by a trusted entity. This contract does not try to protect itself against malicious calls.
* The sGYD Vault is a yield-bearing vault contract that acts as one of the venues that receive GYD yield.


### Manager Contract

The amount of GYD to mint is provided as an input.

This contract allows a distribution manager address to distribute yield to one of three destinations. The destination determines the way the distribution is performed and the data that needs to be encoded.

1. sGYD Vault
   * The recipient must be the sGYD contract
   * Data argument must be the start and end of the stream ABI encoded as (uint256, uint256)
2. L1 Balancer Gauge
   * The recipient must be a Balancer gauge contract
   * Data argument is ignored
3. L2 (sGYD L2 Vault or Balancer L2 Gauge)
   * The transaction will be sent to the `L1GydEscrow`
   * The recipient must be the L2 distributor contract of the target chain
   * Data must the CCIP chain selector and the L2 Distribution ABI-encoded `(uint256, Distribution)`
   * The `distributeGYD` function of the L2 distributor contract will be called with the encoded Distribution data when the GYD is bridged to the target chain

There are restrictions on minting more GYD. Specifically, `setMaxRate` sets the maximum amount of GYD that can be distributed, set as a percentage of the total supply of GYD. The rate is designed as a very basic protection against a bug in the distribution logic but is not designed to be a security feature in the case where `distributeGYD` would be called by a malicious party.

## sGYD Vault

sGYD follows a standard yield-bearing vault design: users deposit GYD and receive sGYD as a share of the total supply.
The vault is exchangeRate based, where the exchange rate is defined as `totalAssets (GYD) / totalSupply (sGYD)`.

The yield is transferred to the vault all in one go, but internally the vault only increases its exchange rate slowly over time until the GYD yield is fully disbursed.

`totalAssets` is computed using current balance and "incoming" yield.
* The incoming yield is accumulated over a period of time
* There can be up to 10 incoming yield streams at any one time (10 is an arbitrary number to prevent the system from running out of gas with too many streams)  
    For example, the sGYD Vault contract could receive one stream of e.g., [100 GYD of yield distributed over 5 days] and the next day another stream of e.g., [500 more GYD distributed over 15 days].
* The yield is accumulated on a per-second basis over the given period

