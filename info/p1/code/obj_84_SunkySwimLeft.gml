// object SunkySwimLeft sprite 70 parent -100 depth 0 persistent false
// ===== event type 0 num 0
// action lib1 id101 kind0 action_move applies-1 relfalse (000100000 | 2)
view_object[0] = SunkySwimLeft

// ===== event type 3 num 0
if keyboard_check(vk_up)
{
if keyboard_check(vk_left)
hspeed-=10
vspeed-=10
}
if keyboard_check(vk_down)
{
if keyboard_check(vk_left)
hspeed-=10
vspeed=10
}

// ===== event type 4 num 87
// action lib1 id202 kind0 action_change_object applies-1 relfalse (85 | 1)
// ===== event type 4 num 72
// action lib1 id101 kind0 action_move applies-1 relfalse (000010000 | 0)
// ===== event type 4 num 1
// action lib1 id101 kind0 action_move applies-1 relfalse (000010000 | 0)
// ===== event type 5 num 40
// action lib1 id101 kind0 action_move applies-1 relfalse (010000000 | 10)
// ===== event type 5 num 39
// action lib1 id202 kind0 action_change_object applies-1 relfalse (85 | 1)
// ===== event type 5 num 38
// action lib1 id101 kind0 action_move applies-1 relfalse (000000010 | 4)
// ===== event type 5 num 37
// action lib1 id101 kind0 action_move applies-1 relfalse (000100000 | 10)
// ===== event type 10 num 40
// action lib1 id101 kind0 action_move applies-1 relfalse (010000000 | 2)
// ===== event type 10 num 38
// action lib1 id101 kind0 action_move applies-1 relfalse (000000010 | 2)
// ===== event type 10 num 37
// action lib1 id101 kind0 action_move applies-1 relfalse (000100000 | 2)
