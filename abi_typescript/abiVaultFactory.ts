// This file is auto-generated. Do not edit manually.

export const abiVaultFactory = [
  {
    type: 'constructor',
    inputs: [
      {
        name: 'TERMMAX_VAULT_IMPLEMENTATION_',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'TERMMAX_VAULT_IMPLEMENTATION',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'createVault',
    inputs: [
      {
        name: 'initialParams',
        type: 'tuple',
        internalType: 'struct VaultInitialParams',
        components: [
          {
            name: 'admin',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'curator',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'timelock',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'asset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'maxCapacity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'name',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'symbol',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'performanceFeeRate',
            type: 'uint64',
            internalType: 'uint64',
          },
        ],
      },
      {
        name: 'salt',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: 'vault',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'predictVaultAddress',
    inputs: [
      {
        name: 'deployer',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'asset',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'name',
        type: 'string',
        internalType: 'string',
      },
      {
        name: 'symbol',
        type: 'string',
        internalType: 'string',
      },
      {
        name: 'salt',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: 'vault',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'CreateMarket',
    inputs: [
      {
        name: 'market',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'collateral',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'debtToken',
        type: 'address',
        indexed: true,
        internalType: 'contract IERC20',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'CreateVault',
    inputs: [
      {
        name: 'vault',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'creator',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'initialParams',
        type: 'tuple',
        indexed: true,
        internalType: 'struct VaultInitialParams',
        components: [
          {
            name: 'admin',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'curator',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'timelock',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'asset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'maxCapacity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'name',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'symbol',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'performanceFeeRate',
            type: 'uint64',
            internalType: 'uint64',
          },
        ],
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'SetGtImplement',
    inputs: [
      {
        name: 'key',
        type: 'bytes32',
        indexed: false,
        internalType: 'bytes32',
      },
      {
        name: 'gtImplement',
        type: 'address',
        indexed: false,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'error',
    name: 'CantNotFindGtImplementation',
    inputs: [],
  },
  {
    type: 'error',
    name: 'FailedDeployment',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InsufficientBalance',
    inputs: [
      {
        name: 'balance',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'needed',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidImplementation',
    inputs: [],
  },
] as const;
