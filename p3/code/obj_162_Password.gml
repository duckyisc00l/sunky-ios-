// object Password sprite 140 parent -100 depth 0 persistent false
// ===== event type 6 num 11
// action lib1 id541 kind0 action_sprite_set applies-1 relfalse (140 | 0 | 1)
// ===== event type 6 num 10
// action lib1 id541 kind0 action_sprite_set applies-1 relfalse (141 | 0 | 1)
// ===== event type 6 num 0
Unlock = get_string("Enter dat password","Punch in dose digits. I mean letters.")
if Unlock = "FINAL" 
{
room_goto_next()
}
else 
{
show_message("WRONG!")
}

