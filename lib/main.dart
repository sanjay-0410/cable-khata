import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadLentBorrowedRecords();
  await loadTransactions();

  runApp(const CableKhataApp());
}
class CableKhataApp extends StatelessWidget {
  const CableKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cable Khata',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> customers = [];
  List<Customer> filteredCustomers = [];

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCustomers();

    searchController.addListener(() {
      filterCustomers();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCustomers =
        prefs.getStringList('customers') ?? [];

    final loadedCustomers = <Customer>[];

    for (final item in savedCustomers) {
      final parts = item.split('|');

      if (parts.length == 3) {
        loadedCustomers.add(
          Customer(
            name: parts[0],
            mobile: parts[1],
            monthlyFee:
            double.tryParse(parts[2]) ?? 300,
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      customers = loadedCustomers;
      filteredCustomers = loadedCustomers;
    });
  }

  void filterCustomers() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredCustomers = customers;
      } else {
        filteredCustomers = customers.where((customer) {
          return customer.name
              .toLowerCase()
              .contains(query) ||
              customer.mobile.contains(query);
        }).toList();
      }
    });
  }

  Future<void> deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Customer'),
          content: Text(
            'Are you sure you want to delete ${customer.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    customers.remove(customer);

    final prefs = await SharedPreferences.getInstance();

    final savedCustomers = customers.map((customer) {
      return '${customer.name}|${customer.mobile}|${customer.monthlyFee}';
    }).toList();

    await prefs.setStringList(
      'customers',
      savedCustomers,
    );

    filterCustomers();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Customer deleted'),
      ),
    );
  }

  Future<void> openCustomer(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerDetailsScreen(
              customer: customer,
            ),
      ),
    );

    await loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search customer',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    searchController.clear();
                  },
                  icon: const Icon(Icons.clear),
                )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: filteredCustomers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 70,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    customers.isEmpty
                        ? 'No customers yet'
                        : 'No matching customers',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer =
                filteredCustomers[index];

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        customer.name[0]
                            .toUpperCase(),
                      ),
                    ),

                    title: Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(customer.mobile),
                        const SizedBox(height: 3),
                        Text(
                          'Monthly Plan: ₹${customer.monthlyFee.toStringAsFixed(0)}',
                        ),
                      ],
                    ),

                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          deleteCustomer(customer);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),

                    onTap: () {
                      openCustomer(customer);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final nameController = TextEditingController();
          final mobileController = TextEditingController();
          final feeController = TextEditingController(text: '300');

          await showDialog(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Add Customer'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: feeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monthly Plan Amount',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Cancel'),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final mobile = mobileController.text.trim();
                      final fee =
                          double.tryParse(feeController.text.trim()) ?? 300;

                      if (name.isEmpty || mobile.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter customer name and mobile number',
                            ),
                          ),
                        );
                        return;
                      }

                      final newCustomer = Customer(
                        name: name,
                        mobile: mobile,
                        monthlyFee: fee,
                      );

                      customers.add(newCustomer);

                      final prefs = await SharedPreferences.getInstance();

                      final savedCustomers = customers.map((customer) {
                        return '${customer.name}|${customer.mobile}|${customer.monthlyFee}';
                      }).toList();

                      await prefs.setStringList(
                        'customers',
                        savedCustomers,
                      );

                      Navigator.pop(dialogContext);

                      await loadCustomers();

                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );

          nameController.dispose();
          mobileController.dispose();
          feeController.dispose();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Settings screen',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

class Customer {
  final String name;
  final String mobile;
  final double monthlyFee;

  Customer({
    required this.name,
    required this.mobile,
    required this.monthlyFee,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Customer> customers = [];

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCustomers = prefs.getStringList('customers') ?? [];

    if (!mounted) return;

    setState(() {
      customers.clear();

      for (final item in savedCustomers) {
        final parts = item.split('|');

        if (parts.length == 3) {
          customers.add(
            Customer(
              name: parts[0],
              mobile: parts[1],
              monthlyFee: double.tryParse(parts[2]) ?? 300,
            ),
          );
        }
      }
    });
  }

  Future<void> saveCustomers() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCustomers = customers
        .map(
          (customer) =>
      '${customer.name}|${customer.mobile}|${customer.monthlyFee}',
    )
        .toList();

    await prefs.setStringList('customers', savedCustomers);
  }

  void addCustomer() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final feeController = TextEditingController(text: '300');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Customer'),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    hintText: 'Enter customer name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'Enter mobile number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Plan Amount',
                    hintText: 'Example: 300',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final mobile = mobileController.text.trim();
                final fee =
                    double.tryParse(feeController.text.trim()) ?? 300;

                if (name.isEmpty || mobile.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter customer name and mobile number',
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  customers.add(
                    Customer(
                      name: name,
                      mobile: mobile,
                      monthlyFee: fee,
                    ),
                  );
                });

                await saveCustomers();

                if (!mounted) return;

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Customer added successfully'),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void openCustomer(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsScreen(
          customer: customer,
        ),
      ),
    );
  }

  Widget buildCustomerList() {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 70,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'No customers yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Add your first cable customer',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: addCustomer,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Customer'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase()
                    : '?',
              ),
            ),

            title: Text(
              customer.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            subtitle: Text(
              '${customer.mobile}\nMonthly Plan: ₹${customer.monthlyFee.toStringAsFixed(0)}',
            ),

            isThreeLine: true,

            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 18,
            ),

            onTap: () {
              openCustomer(customer);
            },
          ),
        );
      },
    );
  }

  Widget buildHomeTab() {
    return Column(
      children: [
        // Today's Summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          title: 'To Receive',
                          amount: '₹0',
                          icon: Icons.arrow_downward,
                        ),
                      ),

                      Expanded(
                        child: _SummaryItem(
                          title: 'Received',
                          amount: '₹0',
                          icon: Icons.arrow_upward,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Customers heading
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              TextButton(
                onPressed: () {
                  setState(() {
                    selectedIndex = 1;
                  });
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),

        Expanded(
          child: buildCustomerList(),
        ),
      ],
    );
  }

  Widget buildCustomersTab() {
    return buildCustomerList();
  }

  Widget buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: const Text(
              'Cable Khata',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Cable operator account',
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_rupee),
            title: const Text('Default Monthly Plan'),
            subtitle: const Text(
              'New customers currently use ₹300',
            ),
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Payment Reminders'),
            subtitle: const Text(
              'Send reminders to customers with pending dues',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Reminder settings will be added next',
                  ),
                ),
              );
            },
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Import Khatabook Data'),
            subtitle: const Text(
              'Import old transactions from a PDF',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'PDF import will be added next',
                  ),
                ),
              );
            },
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Cable Khata'),
            subtitle: const Text(
              'Customer and cable payment management',
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCurrentBody() {
    switch (selectedIndex) {
      case 0:
        return buildHomeTab();

      case 1:
        return buildCustomersTab();

      case 2:
        return const TransactionsScreen();

      case 3:
        return const LentBorrowedScreen();

      case 4:
        return buildSettingsTab();

      default:
        return buildHomeTab();
    }
  }

  String get currentTitle {
    switch (selectedIndex) {
      case 0:
        return 'Cable Khata';

      case 1:
        return 'Customers';

      case 2:
        return '';

      case 3:
        return '';

      case 4:
        return 'Settings';

      default:
        return 'Cable Khata';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRootAppBar = selectedIndex != 2 && selectedIndex != 3;

    return Scaffold(
      appBar: showRootAppBar
          ? AppBar(
        title: Text(
          currentTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: selectedIndex == 0
            ? [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Customer search will be added next',
                  ),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ]
            : null,
      )
          : null,

      body: buildCurrentBody(),

      floatingActionButton: selectedIndex == 0 || selectedIndex == 1
          ? FloatingActionButton.extended(
        onPressed: addCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      )
          : null,

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,

        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),

          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),

          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Lent & Borrowed',
          ),

          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;

  const _SummaryItem({
    required this.title,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 28,
        ),

        const SizedBox(height: 6),

        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          amount,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  double paidAmount = 0;
  final List<double> payments = [];

  double get monthlyFee => widget.customer.monthlyFee;

  double get totalDue {
    final due = monthlyFee - paidAmount;
    return due < 0 ? 0 : due;
  }

  @override
  void initState() {
    super.initState();
    loadPayments();
  }

  Future<void> loadPayments() async {
    final prefs = await SharedPreferences.getInstance();

    final savedPayments =
        prefs.getStringList('payments_${widget.customer.mobile}') ?? [];

    final loadedPayments =
    savedPayments.map((value) => double.tryParse(value) ?? 0).toList();

    if (!mounted) return;

    setState(() {
      payments.clear();
      payments.addAll(loadedPayments);
      paidAmount = loadedPayments.fold(0, (sum, amount) => sum + amount);
    });
  }

  Future<void> savePayments() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'payments_${widget.customer.mobile}',
      payments.map((amount) => amount.toString()).toList(),
    );
  }

  Future<void> addPayment() async {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Payment'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Payment Amount',
              prefixText: '₹ ',
              hintText: 'Enter amount',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(
                  amountController.text.trim(),
                );

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                    ),
                  );
                  return;
                }

                setState(() {
                  paidAmount += amount;
                  payments.add(amount);
                });
                transactions.add({
                  'name': widget.customer.name,
                  'amount': amount,
                  'type': 'Customer Payment',
                  'description': 'Cable bill payment',
                  'date': DateTime.now().toIso8601String(),
                });

                await saveTransactions();

                await savePayments();

                if (!mounted) return;

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Payment of ₹${amount.toStringAsFixed(0)} added',
                    ),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> sendReminder() async {
    final message =
        'Hello ${widget.customer.name}, your cable bill is due. '
        'Pending amount: ₹${totalDue.toStringAsFixed(0)}. '
        'Please make the payment. Thank you.';

    final uri = Uri(
      scheme: 'sms',
      path: widget.customer.mobile,
      queryParameters: {
        'body': message,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the messaging app'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                        widget.customer.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customer.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          widget.customer.mobile,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Account Summary
            const Text(
              'Account Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monthly Fee'),
                        Text(
                          '₹${monthlyFee.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Paid'),
                        Text(
                          '₹${paidAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 30),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Due',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${totalDue.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Add Payment
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: addPayment,
                icon: const Icon(Icons.add),
                label: const Text('Add Payment'),
              ),
            ),

            const SizedBox(height: 10),

            // Send Reminder
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: sendReminder,
                icon: const Icon(
                  Icons.notifications_outlined,
                ),
                label: const Text('Send Reminder'),
              ),
            ),

            const SizedBox(height: 24),

            // Payment History
            const Text(
              'Payment History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: payments.isEmpty
                  ? const Center(
                child: Text(
                  'No payments yet',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.check),
                      ),
                      title: Text(
                        'Payment ₹${payment.toStringAsFixed(0)}',
                      ),
                      subtitle: const Text(
                        'Payment recorded',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class LentBorrowedScreen extends StatelessWidget {
  const LentBorrowedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lent & Borrowed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.arrow_upward),
                ),
                title: const Text(
                  'Money Lent',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Money you gave to someone',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MoneyLentScreen(),
                  ),
                );
              },
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.arrow_downward),
                ),
                title: const Text(
                  'Money Borrowed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Money you borrowed from someone',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MoneyBorrowedScreen(),
                  ),
                );
              },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
final List<Map<String, dynamic>> lentRecords = [];
final List<Map<String, dynamic>> borrowedRecords = [];
final List<Map<String, dynamic>> transactions = [];

Future<void> loadTransactions() async {
  final prefs = await SharedPreferences.getInstance();

  final savedTransactions =
  prefs.getString('transactions');

  if (savedTransactions != null) {
    transactions
      ..clear()
      ..addAll(
        List<Map<String, dynamic>>.from(
          jsonDecode(savedTransactions),
        ),
      );
  }
}

Future<void> saveTransactions() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(
    'transactions',
    jsonEncode(transactions),
  );
}

Future<void> loadLentBorrowedRecords() async {
  final prefs = await SharedPreferences.getInstance();

  final savedLent = prefs.getString('lent_records');
  final savedBorrowed = prefs.getString('borrowed_records');

  if (savedLent != null) {
    lentRecords
      ..clear()
      ..addAll(
        List<Map<String, dynamic>>.from(
          jsonDecode(savedLent),
        ),
      );
  }

  if (savedBorrowed != null) {
    borrowedRecords
      ..clear()
      ..addAll(
        List<Map<String, dynamic>>.from(
          jsonDecode(savedBorrowed),
        ),
      );
  }
}

Future<void> saveLentBorrowedRecords() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(
    'lent_records',
    jsonEncode(lentRecords),
  );

  await prefs.setString(
    'borrowed_records',
    jsonEncode(borrowedRecords),
  );
}

class MoneyLentScreen extends StatefulWidget {
  const MoneyLentScreen({super.key});

  @override
  State<MoneyLentScreen> createState() => _MoneyLentScreenState();
}

class _MoneyLentScreenState extends State<MoneyLentScreen> {

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Money Lent'),
),
body: lentRecords.isEmpty
? const Center(
child: Text(
'No money lent records yet',
style: TextStyle(fontSize: 18),
),
)
    : ListView.builder(
padding: const EdgeInsets.all(16),
itemCount: lentRecords.length,
itemBuilder: (context, index) {
final record = lentRecords[index];

return Card(
child: ListTile(
leading: const CircleAvatar(
child: Icon(Icons.arrow_upward),
),
title: Text(
record['name'],
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
  subtitle: Text(
    record['description'] ?? 'No description',
  ),
trailing: Text(
'₹${record['amount'].toStringAsFixed(0)}',
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
);
},
),
floatingActionButton: FloatingActionButton.extended(
onPressed: () async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const AddLentScreen(),
    ),
  );

  setState(() {});
},
icon: const Icon(Icons.add),
label: const Text('Add Lent'),
),
);
}
}

class AddLentScreen extends StatefulWidget {
  const AddLentScreen({super.key});

  @override
  State<AddLentScreen> createState() => _AddLentScreenState();
}

class _AddLentScreenState extends State<AddLentScreen> {
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> saveLent() async {
  final name = nameController.text.trim();
  final amount = double.tryParse(amountController.text.trim());
  final description = descriptionController.text.trim();

  if (name.isEmpty || amount == null || amount <= 0) {
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
  content: Text('Please enter a name and valid amount'),
  ),
  );
  return;
  }

  lentRecords.add({
    'name': name,
    'amount': amount,
    'description': description,
  });

  transactions.add({
    'name': name,
    'amount': amount,
    'type': 'Money Lent',
    'description': description,
    'date': DateTime.now().toIso8601String(),
  });

  await saveLentBorrowedRecords();
  await saveTransactions();

  Navigator.pop(context);

  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text(
  '₹${amount.toStringAsFixed(0)} lent to $name',
  ),
  ),
  );
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
  appBar: AppBar(
  title: const Text('Add Money Lent'),
  ),
  body: Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
  children: [
  TextField(
  controller: nameController,
  decoration: const InputDecoration(
  labelText: 'Person Name',
  hintText: 'Enter person name',
  border: OutlineInputBorder(),
  ),
  ),

  const SizedBox(height: 16),

  TextField(
  controller: amountController,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(
  labelText: 'Amount',
  hintText: 'Enter amount',
  prefixText: '₹ ',
  border: OutlineInputBorder(),
  ),
  ),
    const SizedBox(height: 16),

    TextField(
      controller: descriptionController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Description',
        hintText: 'Enter a note or description',
        border: OutlineInputBorder(),
      ),
    ),

  const SizedBox(height: 24),

  SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
  onPressed: saveLent,
  icon: const Icon(Icons.save),
  label: const Text('Save Lent'),
  ),
  ),
  ],
  ),
  ),
  );
  }
}
class MoneyBorrowedScreen extends StatefulWidget {
  const MoneyBorrowedScreen({super.key});

  @override
  State<MoneyBorrowedScreen> createState() => _MoneyBorrowedScreenState();
}

class _MoneyBorrowedScreenState extends State<MoneyBorrowedScreen> {
  final descriptionController = TextEditingController();
  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> addBorrowed() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Money Borrowed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Person Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final amount =
                double.tryParse(amountController.text.trim());
                final description = descriptionController.text.trim();

                if (name.isEmpty || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a name and valid amount'),
                    ),
                  );
                  return;
                }

                setState(() {
                  borrowedRecords.add({
                    'name': name,
                    'amount': amount,
                    'description': description,
                  });

                  transactions.add({
                    'name': name,
                    'amount': amount,
                    'type': 'Money Borrowed',
                    'description': description,
                    'date': DateTime.now().toIso8601String(),
                  });
                });

                await saveLentBorrowedRecords();
                await saveTransactions();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '₹${amount.toStringAsFixed(0)} borrowed from $name',
                    ),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Borrowed'),
      ),
      body: borrowedRecords.isEmpty
          ? const Center(
        child: Text(
          'No money borrowed records yet',
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: borrowedRecords.length,
        itemBuilder: (context, index) {
          final record = borrowedRecords[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: Text(record['name']),
              subtitle: Text(
                (record['description'] ?? '').toString().isEmpty
                    ? 'Money Borrowed'
                    : record['description'].toString(),
              ),
              trailing: Text(
                '₹${record['amount'].toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addBorrowed,
        icon: const Icon(Icons.add),
        label: const Text('Add Borrowed'),
      ),
    );
  }
}
class AddBorrowedScreen extends StatefulWidget {
  const AddBorrowedScreen({super.key});

  @override
  State<AddBorrowedScreen> createState() => _AddBorrowedScreenState();
}

class _AddBorrowedScreenState extends State<AddBorrowedScreen> {
  final nameController = TextEditingController();
  final amountController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void saveBorrowed() {
    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text.trim());

    borrowedRecords.add({
      'name': name,
      'amount': amount,
    });

    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name and valid amount'),
        ),
      );
      return;
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '₹${amount.toStringAsFixed(0)} borrowed from $name',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money Borrowed'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Person Name',
                hintText: 'Enter person name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: saveBorrowed,
                icon: const Icon(Icons.save),
                label: const Text('Save Borrowed'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
String _formatTransactionDate(dynamic value) {
  if (value == null || value.toString().isEmpty) {
    return 'Unknown';
  }

  final date = DateTime.tryParse(value.toString());

  if (date == null) {
    return value.toString();
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year;

  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year, $hour:$minute $period';
}
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});
  String _formatTransactionDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: transactions.isEmpty
          ? const Center(
        child: Text(
          'No transactions yet',
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];

          final name = transaction['name'] ?? '';
          final amount = transaction['amount'] ?? 0;
          final type = transaction['type'] ?? '';
          final description =
              transaction['description'] ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  type == 'Money Lent'
                      ? Icons.arrow_upward
                      : type == 'Money Borrowed'
                      ? Icons.arrow_downward
                      : Icons.payments,
                ),
              ),

              title: Text(
                name.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.toString()),

                  if (description.toString().isNotEmpty)
                    Text(
                      description.toString(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),

                  Text(
                    'Date: ${_formatTransactionDate(transaction['date'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                '₹${double.parse(amount.toString()).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
