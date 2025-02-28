import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures operator registration works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const operator1 = accounts.get('wallet_1')!;
    
    // Pre-mint tokens for testing
    let block = chain.mineBlock([
      Tx.contractCall('node-vault', 'mint', 
        [types.uint(100000), types.principal(operator1.address)], 
        deployer.address)
    ]);
    
    // Test registration
    block = chain.mineBlock([
      Tx.contractCall('node-vault', 'register-operator',
        [types.ascii("TestNode1"), types.uint(50000)],
        operator1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify registration
    const response = chain.callReadOnlyFn(
      'node-vault',
      'get-operator-info',
      [types.principal(operator1.address)],
      deployer.address
    );
    
    response.result.expectOk().expectSome();
  }
});

Clarinet.test({
  name: "Tests staking functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const operator1 = accounts.get('wallet_1')!;
    
    // Setup: mint and register
    let block = chain.mineBlock([
      Tx.contractCall('node-vault', 'mint',
        [types.uint(100000), types.principal(operator1.address)],
        deployer.address),
      Tx.contractCall('node-vault', 'register-operator',
        [types.ascii("TestNode1"), types.uint(50000)],
        operator1.address)
    ]);
    
    // Test additional staking
    block = chain.mineBlock([
      Tx.contractCall('node-vault', 'stake-tokens',
        [types.uint(10000)],
        operator1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify total staked amount
    const response = chain.callReadOnlyFn(
      'node-vault',
      'get-total-staked',
      [],
      deployer.address
    );
    
    response.result.expectOk().expectUint(60000);
  }
});

Clarinet.test({
  name: "Tests uptime recording and rewards",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const operator1 = accounts.get('wallet_1')!;
    
    // Setup
    let block = chain.mineBlock([
      Tx.contractCall('node-vault', 'mint',
        [types.uint(100000), types.principal(operator1.address)],
        deployer.address),
      Tx.contractCall('node-vault', 'register-operator',
        [types.ascii("TestNode1"), types.uint(50000)],
        operator1.address)
    ]);
    
    // Record uptime
    block = chain.mineBlock([
      Tx.contractCall('node-vault', 'record-uptime',
        [types.principal(operator1.address), types.uint(98)],
        deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Mine blocks to advance cycle
    chain.mineEmptyBlockUntil(150);
    
    // Claim rewards
    block = chain.mineBlock([
      Tx.contractCall('node-vault', 'claim-rewards',
        [],
        operator1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk();
  }
});
