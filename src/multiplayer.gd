extends Node
var network_active = false
var peer:NetworkedMultiplayerENet
var color := Color.green
var nickname = "EMPTY NICK"
var enemy_nickname = "EMPTY NICKNAME"
var max_rounds:int = 5

var mouse_sensitivity = 0.1

var last_time:int


###узлы
var world:Spatial
var player:Spatial
var enemy:Spatial
var spawn_host:Spatial
var spawn_client:Spatial

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")

func _process(delta):
	if get_tree().has_network_peer():
		if get_tree().get_network_connected_peers().size() >= 1:
			rpc_unreliable("_set_pos", player.transform)

#функция создания сервера
func server_create():
	get_tree().network_peer = null
	peer = NetworkedMultiplayerENet.new()
	peer.always_ordered = false
	peer.transfer_mode = NetworkedMultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	peer.create_server(6969, 10)
	get_tree().network_peer = peer
	_respawn()
	print("server created\nNetwork_id:", get_tree().get_network_unique_id())
	print("My_Nick: ", Multiplayer.nickname)
	print("My_Color: ", Multiplayer.color)

#функция подключения к серверу
#ip - ip адрес
func server_connect(ip:String):
	peer = NetworkedMultiplayerENet.new()
	peer.always_ordered = false
	peer.transfer_mode = NetworkedMultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	peer.create_client(ip, 6969)
	get_tree().network_peer = peer
	_respawn()
	print("connecting to server with ip ", ip,"\nNetwork_id: ",get_tree().get_network_unique_id())
	print("My_Nick: ", Multiplayer.nickname)
	print("My_Color: ", Multiplayer.color)

#функция показа одного сообщения у всех игроков
#message - текст сообщения
#time - кол-во секунд, которое отводится на показ сообщения
func notificate(message:String, time:float):
	rpc("_notificate", message, time)
remotesync func _notificate(message:String, time:float):
	player.notificate(message, time)
	print(message)

#функция нанесения урона. ВНИМАНИЕ: урон нанесётся ВСЕМ игрокам, кроме того, кто вызывал функцию
#damage - кол-во урона
func damage(damage:float):
	rpc("_take_hit", damage)
remote func _take_hit(damage:float):
	player.take_hit(damage)

#функция передачи одного очка. ВНИМАНИЕ: очко передаётся ВСЕМ игрокам, кроме того, кто вызвал функцию
func pass_score():
	rpc("_score")
remote func _score():
	player.get_score()
	print( "+1 score to ", nickname)

#функция респавна ВСЕХ игроков. Хост и клиент респавнятся в заранее заготовленных точках.
func respawn():
	rpc("_respawn")
remotesync func _respawn():
	player.hp = player.max_hp
	player.can_control = true
	if get_tree().get_network_unique_id() == 1:
		player.global_transform = spawn_host.global_transform
	else:
		player.global_transform = spawn_client.global_transform

#функция победы.
#message - сообщение о победе
func win(message:String):
	notificate(message + "\nМатч будет перезапущен через 10 секунд", 5)
	$win_timer.start(10)
	pass


#обработка события коннекта игрока
func _player_connected(id):
	rpc("update_player_info", nickname, color, max_rounds)
	network_active = true

#обработка события дисконекта игрока
func _player_disconnected(id):
	network_active = false
	player.notificate( enemy_nickname + " Disconnected", 2 )
	print( enemy_nickname + " Disconnected" )

#rpc функция обновления данных игрока
#nick - никнейм игрока
#col - цвет игрока
remote func update_player_info(nick:String, col:Color, rounds:int):
	enemy_nickname = nick
	enemy.change_color(col)
	max_rounds = rounds
	player.notificate( enemy_nickname + " Connected", 2)
	ping()
	pass

#rpc функция обновления трансформаций противника
#trans - трансформация (origin, rotation, scale)
remote func _set_pos(trans:Transform):
	enemy.set_pos(trans)

#rpc функция перезагрузки у ВСЕХ игроков.
remotesync func restart_game():
	get_tree().reload_current_scene()
	call_deferred("_respawn")
	print("Match restarted")

#функция создания снаряда
#start - точка, из которой снаряд вылетел
#accel - вектор ускорения
#vel - вектор начальной скорости
#scale_mod - коэффицент размера
#damage - урон
#color - цвет
#time - POSIX время создания снаряда
#owner - network_id того, кто послал снаряд
remotesync func create_projectile(start:Transform, accel:Vector3, vel:Vector3, scale_mod:float, damage:float, col:Color, time:int, owner_id:int):
	var proj = preload("res://scenes/projectile.tscn").instance()
	world.add_child(proj)
	proj.init(start, accel, vel, scale_mod, damage, col, time, owner_id)


#перезапуск матча после выигрыша
func _on_win_timer_timeout():
	rpc("restart_game")

#проверка пинга
func ping():
	last_time = OS.get_system_time_msecs()
	rpc("_ping_send")
remote func _ping_send():
	rpc("_ping_receive")
remote func _ping_receive():
	var diff = OS.get_system_time_msecs() - last_time
	print("Ping: ~" + str(diff)+"ms")
