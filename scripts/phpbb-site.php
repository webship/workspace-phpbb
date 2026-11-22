<?php
/**
 * Sets a board up for testing, with the board's own code: its settings, the accounts of the test users and the
 * test content. Run by PHP on the command line in the board's folder, the script on standard input:
 *
 *   { printf '<?php $SITE_PAYLOAD = "%s"; ?>' "$payload"; cat phpbb-site.php; } | php -- settings accounts content
 *
 * The verbs, run in the order given:
 *   settings   the settings a test run needs (see board_settings below)
 *   accounts   make the accounts of the payload, or give them back their password, address, kind and groups
 *   cancel     delete the accounts of the payload, with their posts
 *   list       say which accounts of the payload the board has, with their kind, their groups and their posts
 *   content    the test content: forums, topics, replies, a poll, private messages (made once; kept as it is)
 *   tidy       remove what a run that was stopped half way left: the topics and private messages whose title
 *              starts with "Webship test", open reports, the drafts, bookmarks, subscriptions, friends, foes
 *              signatures, poll votes and password reset links of the accounts of the payload
 *   version    print the release of the board
 *
 * The payload is base64 of a JSON object: {"accounts": [{"name", "email", "password", "role"}]}, the role one
 * of founder, moderator, member and newmember. It travels on standard input, never on a command line and never
 * in a file.
 *
 * The same script serves the step pack's build and the Webship Workspace's builder.
 */

if (php_sapi_name() !== 'cli')
{
	exit(1);
}

define('IN_PHPBB', true);
$phpbb_root_path = rtrim(getenv('BOARD_ROOT') ?: getcwd(), '/') . '/';
$phpEx = 'php';

if (!file_exists($phpbb_root_path . 'common.' . $phpEx))
{
	fwrite(STDERR, "No board in {$phpbb_root_path}: run this in the board's folder.\n");
	exit(1);
}

// The board reads the address of a request; the command line has none.
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
$_SERVER['HTTP_USER_AGENT'] = 'site-script';
$_SERVER['REQUEST_METHOD'] = 'GET';
$_SERVER['SERVER_NAME'] = 'localhost';
$_SERVER['SERVER_PORT'] = 80;
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['PHP_SELF'] = '/index.php';

require($phpbb_root_path . 'common.' . $phpEx);
require_once($phpbb_root_path . 'includes/functions_user.' . $phpEx);
require_once($phpbb_root_path . 'includes/functions_admin.' . $phpEx);
require_once($phpbb_root_path . 'includes/functions_posting.' . $phpEx);
require_once($phpbb_root_path . 'includes/functions_privmsgs.' . $phpEx);
require_once($phpbb_root_path . 'includes/functions_content.' . $phpEx);
require_once($phpbb_root_path . 'includes/functions_acp.' . $phpEx);
require_once($phpbb_root_path . 'includes/acp/acp_forums.' . $phpEx);
require_once($phpbb_root_path . 'includes/acp/auth.' . $phpEx);

$user->session_begin(false);
$auth->acl($user->data);
$user->setup(array('common', 'acp/common', 'acp/forums', 'mcp', 'posting'));

$payload = isset($SITE_PAYLOAD) ? json_decode(base64_decode($SITE_PAYLOAD), true) : array();
$accounts = isset($payload['accounts']) ? $payload['accounts'] : array();

/** The prefix of everything a scenario makes: tidy removes what carries it. */
const TEST_PREFIX = 'Webship test';

function say($text)
{
	echo $text . "\n";
}

function fail($text)
{
	fwrite(STDERR, $text . "\n");
	exit(1);
}

/** The id of a special group, by its name (ADMINISTRATORS, GLOBAL_MODERATORS, REGISTERED, NEWLY_REGISTERED). */
function group_id_of($name)
{
	global $db;
	$sql = 'SELECT group_id FROM ' . GROUPS_TABLE . " WHERE group_name = '" . $db->sql_escape($name) . "'";
	$result = $db->sql_query($sql);
	$id = (int) $db->sql_fetchfield('group_id');
	$db->sql_freeresult($result);
	if (!$id)
	{
		fail("The board has no group {$name}.");
	}
	return $id;
}

/** The row of an account, by its user name; false when the board has none. */
function account_row($name)
{
	global $db;
	$sql = 'SELECT * FROM ' . USERS_TABLE . " WHERE username_clean = '" . $db->sql_escape(utf8_clean_string($name)) . "'";
	$result = $db->sql_query($sql);
	$row = $db->sql_fetchrow($result);
	$db->sql_freeresult($result);
	return $row;
}

/** Act as an account: what the board does next (a post, a message), that account does. */
function act_as($name)
{
	global $user, $auth;
	$row = account_row($name);
	if (!$row)
	{
		fail("The board has no account {$name}: make the accounts first.");
	}
	$user->data = array_merge($user->data, $row);
	$user->data['is_registered'] = true;
	$user->data['is_bot'] = false;
	$user->ip = '127.0.0.1';
	$auth->acl($user->data);
}

// ---------------------------------------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------------------------------------

/**
 * The settings a test run needs. Every request of a run comes from one address (the router of the container
 * tool), and a run posts, searches and logs in far faster than a person:
 *   - no waiting time between two posts, two messages or two searches;
 *   - no limit of failed logins per account or per address (the limit would put a visual confirmation on the
 *     login form for the rest of the run), and no visual confirmation on the registration form, so that the
 *     refusals of the form are its own;
 *   - mail sent at once, not in batches by the board's cron;
 *   - a new member stays in the "Newly registered users" group (whose posts wait for approval) whatever the
 *     number of its approved posts: the board's limit of that number is its highest;
 *   - the quick reply on, as most boards have it.
 */
function board_settings()
{
	global $config, $db;
	$settings = array(
		'flood_interval'			=> 0,
		'search_interval'			=> 0,
		'search_anonymous_interval'	=> 0,
		'max_login_attempts'		=> 0,
		'ip_login_limit_max'		=> 0,
		'enable_confirm'			=> 0,
		'email_package_size'		=> 0,
		'email_check_mx'			=> 0,
		'new_member_post_limit'		=> 255,
		'allow_quick_reply'			=> 1,
		'check_dnsbl'				=> 0,
	);
	foreach ($settings as $name => $value)
	{
		$config->set($name, $value);
	}
	// The quick reply is a setting of each forum too.
	$sql = 'UPDATE ' . FORUMS_TABLE . ' SET forum_flags = forum_flags + ' . FORUM_FLAG_QUICK_REPLY . '
		WHERE forum_type = ' . FORUM_POST . ' AND ' . $db->sql_bit_and('forum_flags', log(FORUM_FLAG_QUICK_REPLY, 2), '= 0');
	$db->sql_query($sql);
	say('The settings of a test run are in place.');
}

// ---------------------------------------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------------------------------------

/** The groups of a role: the default one first. */
function groups_of_role($role)
{
	switch ($role)
	{
		case 'founder':
			return array('ADMINISTRATORS', 'GLOBAL_MODERATORS', 'REGISTERED');
		case 'moderator':
			return array('GLOBAL_MODERATORS', 'REGISTERED');
		case 'newmember':
			return array('REGISTERED', 'NEWLY_REGISTERED');
		case 'member':
			return array('REGISTERED');
	}
	fail("An account's role is founder, moderator, member or newmember, not {$role}.");
}

function accounts_add($accounts)
{
	global $db, $config, $auth, $phpbb_container, $phpbb_log;
	$passwords = $phpbb_container->get('passwords.manager');
	$special = array('ADMINISTRATORS', 'GLOBAL_MODERATORS', 'REGISTERED', 'NEWLY_REGISTERED');
	$phpbb_log->disable('admin');

	foreach ($accounts as $account)
	{
		$name = $account['name'];
		$role = $account['role'];
		$groups = groups_of_role($role);
		$type = ($role === 'founder') ? USER_FOUNDER : USER_NORMAL;
		$row = account_row($name);

		if (!$row)
		{
			$user_id = (int) user_add(array(
				'username'		=> $name,
				'user_password'	=> $passwords->hash($account['password']),
				'user_email'	=> $account['email'],
				'group_id'		=> group_id_of($groups[0]),
				'user_timezone'	=> $config['board_timezone'],
				'user_lang'		=> $config['default_lang'],
				'user_type'		=> $type,
				'user_regdate'	=> time(),
				'user_new'		=> ($role === 'newmember') ? 1 : 0,
			));
			if (!$user_id)
			{
				fail("The board did not make the account {$name}.");
			}
			$made = 'made';
		}
		else
		{
			$user_id = (int) $row['user_id'];
			$sql = 'UPDATE ' . USERS_TABLE . ' SET ' . $db->sql_build_array('UPDATE', array(
				'user_password'			=> $passwords->hash($account['password']),
				'user_email'			=> strtolower($account['email']),
				'user_type'				=> $type,
				'user_new'				=> ($role === 'newmember') ? 1 : 0,
				'user_login_attempts'	=> 0,
				'user_inactive_reason'	=> 0,
				'user_inactive_time'	=> 0,
				'user_passchg'			=> time(),
			)) . ' WHERE user_id = ' . $user_id;
			$db->sql_query($sql);
			$made = 'updated';
		}

		// The special groups of the role, and none of the others.
		$has = group_memberships(false, array($user_id));
		$has_ids = $has ? array_map('intval', array_column($has, 'group_id')) : array();
		foreach ($special as $group)
		{
			$group_id = group_id_of($group);
			$wanted = in_array($group, $groups, true);
			if ($wanted && !in_array($group_id, $has_ids, true))
			{
				group_user_add($group_id, array($user_id));
			}
			else if (!$wanted && in_array($group_id, $has_ids, true))
			{
				group_user_del($group_id, array($user_id), false, false, false);
			}
		}
		group_set_user_default(group_id_of($groups[0]), array($user_id), false, true);
		say("{$name}: {$made} ({$role}).");
	}

	$auth->acl_clear_prefetch();
	$phpbb_log->enable('admin');
}

function accounts_cancel($accounts)
{
	$ids = array();
	foreach ($accounts as $account)
	{
		$row = account_row($account['name']);
		if ($row)
		{
			$ids[] = (int) $row['user_id'];
			say("{$account['name']}: deleted.");
		}
		else
		{
			say("{$account['name']}: not there.");
		}
	}
	if ($ids)
	{
		user_delete('remove', $ids);
	}
}

function accounts_list($accounts)
{
	global $db;
	foreach ($accounts as $account)
	{
		$row = account_row($account['name']);
		if (!$row)
		{
			say(sprintf('  %-14s not on the board', $account['name']));
			continue;
		}
		$sql = 'SELECT g.group_name FROM ' . USER_GROUP_TABLE . ' ug, ' . GROUPS_TABLE . ' g
			WHERE ug.group_id = g.group_id AND ug.user_pending = 0 AND ug.user_id = ' . (int) $row['user_id'] . ' ORDER BY g.group_id';
		$result = $db->sql_query($sql);
		$groups = array_column($db->sql_fetchrowset($result), 'group_name');
		$db->sql_freeresult($result);
		$kind = ((int) $row['user_type'] === USER_FOUNDER) ? 'a founder' : (((int) $row['user_type'] === USER_INACTIVE) ? 'inactive' : 'active');
		say(sprintf('  %-14s %-28s %-9s %s posts, in %s', $row['username'], $row['user_email'], $kind, $row['user_posts'], strtolower(implode(', ', $groups))));
	}
}

// ---------------------------------------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------------------------------------

/** The id of a forum by its name; 0 when the board has none. */
function forum_id_of($name)
{
	global $db;
	$sql = 'SELECT forum_id FROM ' . FORUMS_TABLE . " WHERE forum_name = '" . $db->sql_escape($name) . "'";
	$result = $db->sql_query($sql);
	$id = (int) $db->sql_fetchfield('forum_id');
	$db->sql_freeresult($result);
	return $id;
}

/** Make a category or a forum, the way the administration control panel does; returns its id. */
function make_forum($name, $parent_id, $type, $description = '', $status = ITEM_UNLOCKED)
{
	$id = forum_id_of($name);
	if ($id)
	{
		return $id;
	}
	$data = array(
		'parent_id'				=> $parent_id,
		'forum_type'			=> $type,
		'type_action'			=> '',
		'forum_status'			=> $status,
		'forum_parents'			=> '',
		'forum_name'			=> $name,
		'forum_link'			=> '',
		'forum_link_track'		=> false,
		'forum_desc'			=> $description,
		'forum_desc_uid'		=> '',
		'forum_desc_options'	=> 7,
		'forum_desc_bitfield'	=> '',
		'forum_rules'			=> '',
		'forum_rules_uid'		=> '',
		'forum_rules_options'	=> 7,
		'forum_rules_bitfield'	=> '',
		'forum_rules_link'		=> '',
		'forum_image'			=> '',
		'forum_style'			=> 0,
		'display_subforum_list'	=> true,
		'display_subforum_limit'	=> false,
		'display_on_index'		=> true,
		'forum_topics_per_page'	=> 0,
		'enable_indexing'		=> true,
		'enable_icons'			=> false,
		'enable_prune'			=> false,
		'enable_post_review'	=> true,
		'enable_quick_reply'	=> true,
		'enable_shadow_prune'	=> false,
		'prune_days'			=> 7,
		'prune_viewed'			=> 7,
		'prune_freq'			=> 1,
		'prune_old_polls'		=> false,
		'prune_announce'		=> false,
		'prune_sticky'			=> false,
		'prune_shadow_days'		=> 7,
		'prune_shadow_freq'		=> 1,
		'forum_password'		=> '',
		'forum_password_confirm'	=> '',
		'forum_password_unset'	=> false,
		'forum_options'			=> 0,
		'show_active'			=> true,
	);
	$forums = new acp_forums();
	$errors = $forums->update_forum_data($data);
	if ($errors)
	{
		fail("The forum {$name} was not made: " . implode(' ', $errors));
	}
	return (int) $data['forum_id'];
}

/** The id of a topic of a forum by its title; 0 when the forum has none. */
function topic_id_of($forum_id, $title)
{
	global $db;
	$sql = 'SELECT topic_id FROM ' . TOPICS_TABLE . ' WHERE forum_id = ' . (int) $forum_id . " AND topic_title = '" . $db->sql_escape($title) . "'";
	$result = $db->sql_query($sql);
	$id = (int) $db->sql_fetchfield('topic_id');
	$db->sql_freeresult($result);
	return $id;
}

/** Post a topic or a reply as an account, through the board's own posting function; returns the topic's id. */
function post($author, $forum_id, $title, $text, $topic_id = 0, $topic_type = POST_NORMAL, $poll = array())
{
	act_as($author);
	$uid = $bitfield = $options = '';
	generate_text_for_storage($text, $uid, $bitfield, $options, true, true, true);
	$data = array(
		'forum_id'			=> $forum_id,
		'topic_id'			=> $topic_id,
		'icon_id'			=> false,
		'enable_bbcode'		=> true,
		'enable_smilies'	=> true,
		'enable_urls'		=> true,
		'enable_sig'		=> true,
		'message'			=> $text,
		'message_md5'		=> md5($text),
		'bbcode_bitfield'	=> $bitfield,
		'bbcode_uid'		=> $uid,
		'post_edit_locked'	=> 0,
		'topic_title'		=> $title,
		'notify_set'		=> false,
		'notify'			=> false,
		'post_time'			=> 0,
		'topic_time_limit'	=> 0,
		'forum_name'		=> '',
		'enable_indexing'	=> true,
	);
	submit_post($topic_id ? 'reply' : 'post', $title, '', $topic_type, $poll, $data);
	return (int) $data['topic_id'];
}

/** Send a private message from an account to another, through the board's own function. */
function message($from, $to, $subject, $text)
{
	global $db, $user;
	$to_row = account_row($to);
	$sql = 'SELECT p.msg_id FROM ' . PRIVMSGS_TABLE . ' p, ' . PRIVMSGS_TO_TABLE . " t
		WHERE p.msg_id = t.msg_id AND t.user_id = " . (int) $to_row['user_id'] . " AND p.message_subject = '" . $db->sql_escape($subject) . "'";
	$result = $db->sql_query_limit($sql, 1);
	$there = (int) $db->sql_fetchfield('msg_id');
	$db->sql_freeresult($result);
	if ($there)
	{
		return;
	}
	act_as($from);
	$uid = $bitfield = $options = '';
	generate_text_for_storage($text, $uid, $bitfield, $options, true, true, true);
	$data = array(
		'from_user_id'		=> (int) $user->data['user_id'],
		'from_user_ip'		=> $user->ip,
		'from_username'		=> $user->data['username'],
		'enable_sig'		=> false,
		'enable_bbcode'		=> true,
		'enable_smilies'	=> true,
		'enable_urls'		=> true,
		'icon_id'			=> 0,
		'bbcode_bitfield'	=> $bitfield,
		'bbcode_uid'		=> $uid,
		'message'			=> $text,
		'address_list'		=> array('u' => array((int) $to_row['user_id'] => 'to')),
	);
	submit_pm('post', $subject, $data, false);
}

/**
 * The test content. Made once: a forum or a topic that is there already stays as it is.
 *
 *   Community (a category)
 *     General discussion         an announcement (locked), a sticky topic, a topic of two pages, a poll,
 *                                 a topic without a reply
 *       Introductions            a subforum, one topic
 *     Help and support           27 topics: two pages of a forum
 *     Archive                    a locked forum, one topic
 *   Staff (a category)
 *     Staff room                 moderators and administrators only, one topic
 *
 * and two private messages to the member.
 */
function content()
{
	global $db, $auth, $cache;
	$first = forum_id_of('Your first forum');
	if (!$first)
	{
		$sql = 'SELECT forum_id FROM ' . FORUMS_TABLE . ' WHERE forum_type = ' . FORUM_POST . ' ORDER BY forum_id';
		$result = $db->sql_query_limit($sql, 1);
		$first = (int) $db->sql_fetchfield('forum_id');
		$db->sql_freeresult($result);
	}

	$made = array();
	$forum = function ($name, $parent, $type, $description = '', $status = ITEM_UNLOCKED) use (&$made, $first) {
		$new = !forum_id_of($name);
		$id = make_forum($name, $parent, $type, $description, $status);
		if ($new)
		{
			$made[$name] = $id;
		}
		return $id;
	};

	$community = $forum('Community', 0, FORUM_CAT);
	$general = $forum('General discussion', $community, FORUM_POST, 'Talk about anything that fits nowhere else.');
	$intro = $forum('Introductions', $general, FORUM_POST, 'New here? Say hello.');
	$help = $forum('Help and support', $community, FORUM_POST, 'Questions about the board and their answers.');
	$archive = $forum('Archive', $community, FORUM_POST, 'Old topics, kept to read.', ITEM_LOCKED);
	$staff = $forum('Staff', 0, FORUM_CAT);
	$room = $forum('Staff room', $staff, FORUM_POST, 'For the moderators and the administrators.');

	// The permissions of the new forums: the ones of the first forum of the board, the staff's apart.
	$public = array();
	foreach (array('Community', 'General discussion', 'Introductions', 'Help and support', 'Archive') as $name)
	{
		if (isset($made[$name]))
		{
			$public[] = $made[$name];
		}
	}
	if ($public && $first)
	{
		copy_forum_permissions($first, $public, true, false);
	}
	if (isset($made['Staff']) || isset($made['Staff room']))
	{
		$sql = 'SELECT role_id FROM ' . ACL_ROLES_TABLE . " WHERE role_name = 'ROLE_FORUM_FULL'";
		$result = $db->sql_query($sql);
		$full = (int) $db->sql_fetchfield('role_id');
		$db->sql_freeresult($result);
		$admin = new auth_admin();
		foreach (array($staff, $room) as $forum_id)
		{
			foreach (array('ADMINISTRATORS', 'GLOBAL_MODERATORS') as $group)
			{
				$admin->acl_set('group', $forum_id, group_id_of($group), array('f_' => ACL_YES), $full, false);
			}
		}
		$auth->acl_clear_prefetch();
	}
	$cache->destroy('sql', FORUMS_TABLE);

	$topic = function ($author, $forum_id, $title, $text, $type = POST_NORMAL, $poll = array()) {
		$id = topic_id_of($forum_id, $title);
		return $id ? array($id, false) : array(post($author, $forum_id, $title, $text, 0, $type, $poll), true);
	};

	// General discussion.
	list($rules, $new) = $topic('administrator', $general, 'Board rules', "Be kind to each other.\n\n[list=1][*]Stay on topic.[*]No advertising.[*]Report a post that breaks these rules; a moderator will look at it.[/list]", POST_ANNOUNCE);
	if ($new)
	{
		$db->sql_query('UPDATE ' . TOPICS_TABLE . ' SET topic_status = ' . ITEM_LOCKED . ' WHERE topic_id = ' . $rules);
	}
	$topic('moderator', $general, 'Start here: how this board works', "Each forum holds topics, and each topic holds posts.\n\n[b]New topic[/b] starts one; [b]Post reply[/b] answers one.", POST_STICKY);

	list($baking, $new) = $topic('member', $general, 'Weekend baking thread', 'What is in your oven this weekend? Mine holds a [b]sourdough[/b] loaf with a dark crust.');
	if ($new)
	{
		$replies = array(
			array('moderator', 'A tray of cinnamon rolls here.'),
			array('administrator', 'Flatbread on a hot stone, ten minutes a piece.'),
			array('member', 'The sourdough came out well: an open crumb at last.'),
			array('moderator', 'How long did you let the dough rise?'),
			array('member', 'Fourteen hours in the fridge, then two on the counter.'),
			array('administrator', 'That is longer than mine. I will try it.'),
			array('moderator', 'Which flour do you use?'),
			array('member', 'A strong white flour with a fifth of rye.'),
			array('administrator', 'Rye gives it that taste. Good choice.'),
			array('moderator', 'Next weekend: bagels.'),
			array('member', 'Count me in for the bagels.'),
			array('administrator', 'Boil them before you bake them.'),
		);
		foreach ($replies as $reply)
		{
			post($reply[0], $general, 'Re: Weekend baking thread', $reply[1], $baking);
		}
	}

	$topic('member', $general, 'Which season do you like best?', 'Vote, and tell us why.', POST_NORMAL, array(
		'poll_title'		=> 'Which season do you like best?',
		'poll_start'		=> time(),
		'poll_max_options'	=> 1,
		'poll_length'		=> 0,
		'poll_vote_change'	=> 1,
		'poll_options'		=> array('Spring', 'Summer', 'Autumn', 'Winter'),
	));
	$topic('member', $general, 'A walk along the river', 'The path along the river is open again after the winter.');

	$topic('member', $intro, 'Hello from the member', 'I joined today. Glad to be here.');

	// Help and support: two pages of topics.
	for ($n = 1; $n <= 27; $n++)
	{
		$number = sprintf('%02d', $n);
		$topic(($n % 3 === 0) ? 'moderator' : 'member', $help, "Question {$number}: where do I find my drafts?", "Asking for the {$number}. time: the drafts are in the user control panel, under Overview.");
	}

	list($old, $new) = $topic('administrator', $archive, 'Old announcements', 'The announcements of last year, kept to read.');
	$topic('moderator', $room, 'Moderation notes', 'Notes of the moderators. Members do not see this forum.');

	message('administrator', 'member', 'Welcome to the board', 'Welcome. Read the board rules first, then say hello in Introductions.');
	message('moderator', 'member', 'About your first post', 'I moved your first post to Introductions, where it fits better.');

	say('The test content is in place.');
}

// ---------------------------------------------------------------------------------------------------------
// Tidy
// ---------------------------------------------------------------------------------------------------------

function tidy($accounts)
{
	global $db, $config;
	$like = $db->sql_like_expression(TEST_PREFIX . $db->get_any_char());
	$re_like = $db->sql_like_expression('Re: ' . TEST_PREFIX . $db->get_any_char());

	// Topics of a run, whatever their state (waiting for approval, deleted softly, moved).
	$sql = 'SELECT topic_id FROM ' . TOPICS_TABLE . ' WHERE topic_title ' . $like;
	$result = $db->sql_query($sql);
	$topics = array_map('intval', array_column($db->sql_fetchrowset($result), 'topic_id'));
	$db->sql_freeresult($result);
	if ($topics)
	{
		delete_topics('topic_id', $topics);
	}
	// Replies of a run in the topics of the test content.
	$sql = 'SELECT post_id FROM ' . POSTS_TABLE . ' WHERE post_subject ' . $like . ' OR post_subject ' . $re_like . ' OR post_text ' . $db->sql_like_expression($db->get_any_char() . TEST_PREFIX . $db->get_any_char());
	$result = $db->sql_query($sql);
	$posts = array_map('intval', array_column($db->sql_fetchrowset($result), 'post_id'));
	$db->sql_freeresult($result);
	if ($posts)
	{
		delete_posts('post_id', $posts);
	}

	// Private messages of a run.
	$sql = 'SELECT msg_id FROM ' . PRIVMSGS_TABLE . ' WHERE message_subject ' . $like . ' OR message_subject ' . $re_like;
	$result = $db->sql_query($sql);
	$messages = array_map('intval', array_column($db->sql_fetchrowset($result), 'msg_id'));
	$db->sql_freeresult($result);
	if ($messages)
	{
		$db->sql_query('DELETE FROM ' . PRIVMSGS_TO_TABLE . ' WHERE ' . $db->sql_in_set('msg_id', $messages));
		$db->sql_query('DELETE FROM ' . PRIVMSGS_TABLE . ' WHERE ' . $db->sql_in_set('msg_id', $messages));
	}

	// Open reports.
	$db->sql_query('DELETE FROM ' . REPORTS_TABLE);
	$db->sql_query('UPDATE ' . POSTS_TABLE . ' SET post_reported = 0 WHERE post_reported = 1');
	$db->sql_query('UPDATE ' . TOPICS_TABLE . ' SET topic_reported = 0 WHERE topic_reported = 1');
	$db->sql_query('UPDATE ' . PRIVMSGS_TABLE . ' SET message_reported = 0 WHERE message_reported = 1');

	// What the accounts keep for themselves.
	$ids = array();
	foreach ($accounts as $account)
	{
		$row = account_row($account['name']);
		if ($row)
		{
			$ids[] = (int) $row['user_id'];
		}
	}
	if ($ids)
	{
		$in = $db->sql_in_set('user_id', $ids);
		$db->sql_query('DELETE FROM ' . DRAFTS_TABLE . ' WHERE ' . $in);
		$db->sql_query('DELETE FROM ' . BOOKMARKS_TABLE . ' WHERE ' . $in);
		$db->sql_query('DELETE FROM ' . TOPICS_WATCH_TABLE . ' WHERE ' . $in);
		$db->sql_query('DELETE FROM ' . FORUMS_WATCH_TABLE . ' WHERE ' . $in);
		$db->sql_query('DELETE FROM ' . ZEBRA_TABLE . ' WHERE ' . $in);
		$db->sql_query('UPDATE ' . USERS_TABLE . " SET user_sig = '', user_sig_bbcode_uid = '', user_sig_bbcode_bitfield = '', user_login_attempts = 0, reset_token = '', reset_token_expiration = 0 WHERE " . $in);
		// Their votes in the polls of the test content.
		$sql = 'SELECT topic_id, poll_option_id FROM ' . POLL_VOTES_TABLE . ' WHERE ' . $db->sql_in_set('vote_user_id', $ids);
		$result = $db->sql_query($sql);
		$votes = $db->sql_fetchrowset($result);
		$db->sql_freeresult($result);
		foreach ($votes as $vote)
		{
			$db->sql_query('UPDATE ' . POLL_OPTIONS_TABLE . ' SET poll_option_total = poll_option_total - 1 WHERE poll_option_total > 0 AND topic_id = ' . (int) $vote['topic_id'] . ' AND poll_option_id = ' . (int) $vote['poll_option_id']);
		}
		$db->sql_query('DELETE FROM ' . POLL_VOTES_TABLE . ' WHERE ' . $db->sql_in_set('vote_user_id', $ids));
		// The counters of the messages of each account, counted again.
		foreach ($ids as $id)
		{
			$sql = 'SELECT COUNT(msg_id) AS unread FROM ' . PRIVMSGS_TO_TABLE . ' WHERE pm_unread = 1 AND folder_id <> ' . PRIVMSGS_OUTBOX . ' AND user_id = ' . $id;
			$result = $db->sql_query($sql);
			$unread = (int) $db->sql_fetchfield('unread');
			$db->sql_freeresult($result);
			$sql = 'SELECT COUNT(msg_id) AS fresh FROM ' . PRIVMSGS_TO_TABLE . ' WHERE pm_new = 1 AND folder_id IN (' . PRIVMSGS_NO_BOX . ', ' . PRIVMSGS_HOLD_BOX . ') AND user_id = ' . $id;
			$result = $db->sql_query($sql);
			$fresh = (int) $db->sql_fetchfield('fresh');
			$db->sql_freeresult($result);
			$db->sql_query('UPDATE ' . USERS_TABLE . ' SET user_unread_privmsg = ' . $unread . ', user_new_privmsg = ' . $fresh . ' WHERE user_id = ' . $id);
		}
	}

	// The counters of the forums, counted again.
	sync('forum', '', '', false, true);
	say('The board is tidy: ' . count($topics) . ' topics, ' . count($posts) . ' posts and ' . count($messages) . ' private messages of a run removed.');
}

// ---------------------------------------------------------------------------------------------------------

$verbs = array_slice($argv, 1);
if (!$verbs)
{
	fail('Give a verb: settings, accounts, cancel, list, content, tidy, version.');
}
foreach ($verbs as $verb)
{
	switch ($verb)
	{
		case 'settings':
			board_settings();
			break;
		case 'accounts':
			accounts_add($accounts);
			break;
		case 'cancel':
			accounts_cancel($accounts);
			break;
		case 'list':
			accounts_list($accounts);
			break;
		case 'content':
			content();
			break;
		case 'tidy':
			tidy($accounts);
			break;
		case 'version':
			say('phpBB ' . $config['version']);
			break;
		default:
			fail("Unknown verb {$verb}.");
	}
}
$cache->purge();
$user->session_kill(false);
