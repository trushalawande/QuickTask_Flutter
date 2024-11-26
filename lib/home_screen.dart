import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<ParseObject> tasks = [];
  bool _isLoading = true;
  bool _isAdding = false;
  TabController? _tabController; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);  
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController?.dispose();  
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final currentUser = await ParseUser.currentUser() as ParseUser?;
      
      if (currentUser == null) {
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      final QueryBuilder<ParseObject> query =
          QueryBuilder<ParseObject>(ParseObject('Task'))
            ..whereEqualTo('user', ParseObject('_User')..objectId = currentUser.objectId)
            ..orderByDescending('createdAt');

      final response = await query.query();

      if (response.success && response.results != null) {
        if (!mounted) return;
        setState(() {
          tasks = response.results as List<ParseObject>;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error?.message ?? 'Failed to load tasks')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tasks: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addTask() async {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.add_task, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Add New Task'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'What needs to be done?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(Icons.task),
                  ),
                  autofocus: true,
                  maxLength: 50,
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            DateFormat('EEEE, MMM dd, yyyy').format(selectedDate),
                          ),
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    dialogBackgroundColor: Colors.white,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text(selectedTime.format(context)),
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setDialogState(() => selectedTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: _isAdding
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a task title'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      setState(() => _isAdding = true);
                      try {
                        final currentUser = await ParseUser.currentUser() as ParseUser?;
                        if (currentUser == null) throw Exception('User not logged in');

                        // Combine date and time
                        final DateTime dueDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        final task = ParseObject('Task')
                          ..set('title', titleController.text.trim())
                          ..set('dueDate', dueDateTime)
                          ..set('isCompleted', false)
                          ..set('user', ParseObject('_User')..objectId = currentUser.objectId);

                        final response = await task.save();
                        if (response.success) {
                          Navigator.pop(context);
                          _loadTasks();
                        } else {
                          throw Exception(response.error?.message ?? 'Failed to save task');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error adding task: ${e.toString()}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } finally {
                        setState(() => _isAdding = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isAdding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Add Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaskStatus(ParseObject task) async {
    try {
      final currentStatus = task.get<bool>('isCompleted') ?? false;
      task.set('isCompleted', !currentStatus);
      final response = await task.save();
      
      if (response.success) {
        _loadTasks();
      } else {
        throw Exception(response.error?.message ?? 'Failed to update task');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteTask(ParseObject task) async {
    try {
      final response = await task.delete();
      
      if (response.success) {
        _loadTasks();
      } else {
        throw Exception(response.error?.message ?? 'Failed to delete task');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting task: ${e.toString()}')),
      );
    }
  }

  List<ParseObject> _sortTasksByDueDate(List<ParseObject> taskList) {
    return List<ParseObject>.from(taskList)
      ..sort((a, b) {
        final aDate = a.get<DateTime>('dueDate');
        final bDate = b.get<DateTime>('dueDate');
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
  }

  Widget _buildTaskList(List<ParseObject> taskList) {
    if (taskList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'app_icon',
              child: Icon(
                Icons.task_alt,
                size: 80,
                color: Colors.grey.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No tasks yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addTask,
              icon: const Icon(Icons.add),
              label: const Text('Add your first task'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedList(
      initialItemCount: taskList.length,
      itemBuilder: (context, index, animation) {
        final task = taskList[index];
        final isCompleted = task.get<bool>('isCompleted') ?? false;
        final dueDate = task.get<DateTime>('dueDate');
        final isOverdue = !isCompleted && dueDate!.isBefore(DateTime.now());

        return SlideTransition(
          position: animation.drive(Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          )),
          child: Dismissible(
            key: Key(task.objectId!),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteTask(task),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 1,
              shadowColor: Colors.blue.withOpacity(0.1),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isOverdue
                    ? BorderSide(color: Colors.red.shade300, width: 1)
                    : BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.2), width: 1),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      isCompleted 
                          ? Colors.grey.shade50 
                          : Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    task.get<String>('title') ?? '',
                    style: TextStyle(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: isCompleted ? Colors.grey : Colors.black87,
                      fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isOverdue ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(dueDate!),
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: isCompleted,
                      activeColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (_) => _toggleTaskStatus(task),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final incompleteTasks = _sortTasksByDueDate(
      tasks.where((task) => !(task.get<bool>('isCompleted') ?? false)).toList()
    );
    
    final completedTasks = _sortTasksByDueDate(
      tasks.where((task) => task.get<bool>('isCompleted') ?? false).toList()
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('QuickTask', style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        )),
        bottom: TabBar(
          indicatorColor: Theme.of(context).primaryColor,
          controller: _tabController!,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pending_actions),
                  const SizedBox(width: 8),
                  Text('Pending (${incompleteTasks.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.done_all),
                  const SizedBox(width: 8),
                  Text('Done (${completedTasks.length})'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                final user = await ParseUser.currentUser() as ParseUser?;
                if (user != null) {
                  await user.logout();
                }
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error logging out: ${e.toString()}')),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
            stops: const [0.7, 0.9, 1.0],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController!,
                children: [
                  _buildTaskList(incompleteTasks),
                  _buildTaskList(completedTasks),
                ],
              ),
      ),
      floatingActionButton: !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _addTask,
              icon: const Icon(Icons.add),
              label: const Text('New Task'),
            )
          : null,
    );
  }
}