import 'package:dynamic_sdk/dynamic_sdk.dart';
import 'package:dynamic_sdk_web3dart/dynamic_sdk_web3dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

class WalletView extends StatefulWidget {
  final String walletId;
  const WalletView({super.key, required this.walletId});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  final TextEditingController _messageController = TextEditingController(
    text: 'Hello from Dynamic Flutter',
  );
  final TextEditingController _toAddressController = TextEditingController();
  final TextEditingController _amountEthController = TextEditingController();

  String? _lastSignature;
  String? _lastTxHash;
  String? _error;
  bool _busy = false;
  String? _balance;
  bool _loadingBalance = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBalance();
    });
  }

  Future<void> _fetchBalance() async {
    final wallet = _findWallet();
    if (wallet == null) return;
    setState(() {
      _loadingBalance = true;
    });
    try {
      final bal = await DynamicSDK.instance.wallets.getBalance(wallet: wallet);
      setState(() {
        _balance = bal;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingBalance = false;
      });
    }
  }

  BaseWallet? _findWallet() {
    final wallets = DynamicSDK.instance.wallets.userWallets;
    final match = wallets.where((w) => w.id == widget.walletId).toList();
    return match.isNotEmpty ? match.first : null;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _toAddressController.dispose();
    _amountEthController.dispose();
    super.dispose();
  }

  Future<void> _signMessage() async {
    setState(() {
      _busy = true;
      _error = null;
      _lastSignature = null;
    });
    try {
      final wallet = _findWallet();
      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      // How to sign a message using the DynamicSDK
      final sig = await DynamicSDK.instance.wallets.signMessage(
        wallet: wallet,
        message: _messageController.text,
      );
      setState(() {
        _lastSignature = sig;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _sendTransaction() async {
    setState(() {
      _busy = true;
      _error = null;
      _lastTxHash = null;
    });
    try {
      final wallet = _findWallet();
      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      // Only supports EVM for now via web3dart helper
      final to = _toAddressController.text.trim();
      if (to.isEmpty) throw Exception('Recipient address is required');
      final amountStr = _amountEthController.text.trim();
      if (amountStr.isEmpty) throw Exception('Amount is required');

      final amountInWei =
          (double.parse(amountStr) * BigInt.from(10).pow(18).toDouble())
              .toInt();

      // How to send a transaction using the DynamicSDK and web3dart
      final tx = Transaction(
        from: EthereumAddress.fromHex(wallet.address),
        to: EthereumAddress.fromHex(to),
        value: EtherAmount.inWei(BigInt.from(amountInWei)),
      );

      final txHash = await DynamicSDK.instance.web3dart.sendTransaction(
        transaction: tx,
        wallet: wallet,
      );

      setState(() {
        _lastTxHash = txHash;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _mintPlaceholder() async {
    // Placeholder action: replace with real contract call if needed
    setState(() {
      _busy = true;
      _error = null;
      _lastTxHash = null;
      _lastSignature = null;
    });
    try {
      // How to interact with a contract using the DynamicSDK and web3dart
      final wallet = _findWallet();
      if (wallet == null) {
        throw Exception('Wallet not found');
      }

      final network = await DynamicSDK.instance.wallets.getNetwork(
        wallet: wallet,
      );

      final client = DynamicSDK.instance.web3dart.createPublicClient(
        chainId: network.intValue()!,
      );

      final gasPrice = await client.getGasPrice();

      final maxFeePerGas =
          gasPrice.getValueInUnitBI(EtherUnit.wei) * BigInt.from(2);

      final maxPriorityFeePerGas =
          gasPrice.getValueInUnitBI(EtherUnit.wei) * BigInt.from(2);

      final contract = DeployedContract(
        ContractAbi.fromJson(
          '[{"constant":false,"inputs":[{"name":"newMessage","type":"string"}],"name":"update","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"message","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[{"name":"initMessage","type":"string"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"}]',
          '',
        ),
        EthereumAddress.fromHex('0x8b211dfebf490a648f6de859dfbed61fa22f35e0'),
      );

      final updateFunction = contract.function('update');

      final transaction = Transaction.callContract(
        contract: contract,
        maxFeePerGas: EtherAmount.inWei(maxFeePerGas),
        maxPriorityFeePerGas: EtherAmount.inWei(maxPriorityFeePerGas),
        function: updateFunction,
        parameters: [""],
      );

      final transactionHash = await DynamicSDK.instance.web3dart
          .sendTransaction(transaction: transaction, wallet: wallet);

      setState(() {
        _lastTxHash = transactionHash;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mint transaction submitted')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mint failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _findWallet();

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: _fetchBalance,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wallet == null)
                  const Text(
                    'Wallet not found. Go back and select a wallet.',
                    style: TextStyle(color: Colors.red),
                  )
                else
                  _WalletHeader(
                    wallet: wallet,
                    balance: _balance,
                    loadingBalance: _loadingBalance,
                  ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sign Message',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _signMessage,
                            child: const Text('Sign Message'),
                          ),
                        ),
                        if (_lastSignature != null) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            'Signature: $_lastSignature',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Send Transaction (EVM)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _toAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Recipient (0x...)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountEthController,
                          decoration: const InputDecoration(
                            labelText: 'Amount (ETH)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _sendTransaction,
                            child: const Text('Send'),
                          ),
                        ),
                        if (_lastTxHash != null) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            'Tx Hash: $_lastTxHash',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _mintPlaceholder,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Mint'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  final BaseWallet wallet;
  final String? balance;
  final bool loadingBalance;

  const _WalletHeader({
    required this.wallet,
    this.balance,
    this.loadingBalance = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 20,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wallet.address,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  wallet.chain.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy address',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: wallet.address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied to clipboard'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${wallet.id}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Balance: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (loadingBalance)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  balance ?? '-',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
