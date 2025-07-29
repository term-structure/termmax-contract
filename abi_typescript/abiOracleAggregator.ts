// This file is auto-generated. Do not edit manually.

export const abiOracleAggregator = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_owner',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'timeLock',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'acceptOwnership',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'acceptPendingOracle',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getPrice',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [
      {
        name: 'price',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'decimals',
        type: 'uint8',
        internalType: 'uint8',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'oracles',
    inputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [
      {
        name: 'aggregator',
        type: 'address',
        internalType: 'contract AggregatorV3Interface',
      },
      {
        name: 'backupAggregator',
        type: 'address',
        internalType: 'contract AggregatorV3Interface',
      },
      {
        name: 'heartbeat',
        type: 'uint32',
        internalType: 'uint32',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'owner',
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
    name: 'pendingOracles',
    inputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [
      {
        name: 'oracle',
        type: 'tuple',
        internalType: 'struct IOracle.Oracle',
        components: [
          {
            name: 'aggregator',
            type: 'address',
            internalType: 'contract AggregatorV3Interface',
          },
          {
            name: 'backupAggregator',
            type: 'address',
            internalType: 'contract AggregatorV3Interface',
          },
          {
            name: 'heartbeat',
            type: 'uint32',
            internalType: 'uint32',
          },
        ],
      },
      {
        name: 'validAt',
        type: 'uint64',
        internalType: 'uint64',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'pendingOwner',
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
    name: 'renounceOwnership',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'submitPendingOracle',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'oracle',
        type: 'tuple',
        internalType: 'struct IOracle.Oracle',
        components: [
          {
            name: 'aggregator',
            type: 'address',
            internalType: 'contract AggregatorV3Interface',
          },
          {
            name: 'backupAggregator',
            type: 'address',
            internalType: 'contract AggregatorV3Interface',
          },
          {
            name: 'heartbeat',
            type: 'uint32',
            internalType: 'uint32',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'transferOwnership',
    inputs: [
      {
        name: 'newOwner',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'OwnershipTransferStarted',
    inputs: [
      {
        name: 'previousOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'newOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'OwnershipTransferred',
    inputs: [
      {
        name: 'previousOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'newOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'RevokePendingOracle',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'SubmitPendingOracle',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'aggregator',
        type: 'address',
        indexed: true,
        internalType: 'contract AggregatorV3Interface',
      },
      {
        name: 'backupAggregator',
        type: 'address',
        indexed: true,
        internalType: 'contract AggregatorV3Interface',
      },
      {
        name: 'heartbeat',
        type: 'uint32',
        indexed: false,
        internalType: 'uint32',
      },
      {
        name: 'validAt',
        type: 'uint64',
        indexed: false,
        internalType: 'uint64',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'UpdateOracle',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'aggregator',
        type: 'address',
        indexed: true,
        internalType: 'contract AggregatorV3Interface',
      },
      {
        name: 'backupAggregator',
        type: 'address',
        indexed: true,
        internalType: 'contract AggregatorV3Interface',
      },
      {
        name: 'heartbeat',
        type: 'uint32',
        indexed: false,
        internalType: 'uint32',
      },
    ],
    anonymous: false,
  },
  {
    type: 'error',
    name: 'AlreadyPending',
    inputs: [],
  },
  {
    type: 'error',
    name: 'AlreadySet',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InvalidAssetOrOracle',
    inputs: [],
  },
  {
    type: 'error',
    name: 'NoPendingValue',
    inputs: [],
  },
  {
    type: 'error',
    name: 'OracleIsNotWorking',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'OwnableInvalidOwner',
    inputs: [
      {
        name: 'owner',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'OwnableUnauthorizedAccount',
    inputs: [
      {
        name: 'account',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'TimelockNotElapsed',
    inputs: [],
  },
] as const;
