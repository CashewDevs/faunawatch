import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/viewmodels/new_chat_viewmodel.dart';
import 'package:faunawatch/features/messages/views/widgets/chat_user_avatar.dart';

class NewChatView extends ConsumerStatefulWidget {
  const NewChatView({super.key});
  @override
  ConsumerState<NewChatView> createState() => _NewChatViewState();
}

class _NewChatViewState extends ConsumerState<NewChatView> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newChatViewModelProvider);
    final vm = ref.read(newChatViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: vm.search,
              onChanged: vm.onQueryChanged,
              enabled: state.openingUserId == null,
              decoration: InputDecoration(
                labelText: 'Search by username or name',
                suffixIcon: IconButton(
                  tooltip: 'Search users',
                  onPressed: state.openingUserId == null
                      ? () => vm.search(_controller.text)
                      : null,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.error!),
            ),
          if (state.isSearching) const LinearProgressIndicator(),
          Expanded(
            child: state.users.isEmpty
                ? Center(
                    child: Text(
                      state.isSearching
                          ? 'Finding matching people…'
                          : state.hasSearched
                          ? 'No users found.'
                          : 'Type at least two characters to see matching people.',
                    ),
                  )
                : ListView.builder(
                    itemCount: state.users.length,
                    itemBuilder: (context, index) {
                      final user = state.users[index];
                      return ListTile(
                        title: Text(user.name),
                        leading: ChatUserAvatar(user: user),
                        trailing: state.openingUserId == user.id
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(),
                              )
                            : const Icon(Icons.chat_bubble_outline),
                        enabled: state.openingUserId == null,
                        onTap: () async {
                          final thread = await vm.open(user);
                          if (context.mounted && thread != null) {
                            Navigator.of(context).pop<MessageThread>(thread);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
