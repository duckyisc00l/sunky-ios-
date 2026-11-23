// Dumps a GameMaker 8 exe: summary (summary.txt) and every piece of GML (code/).
use gm8exe::asset::CodeAction;
use std::{fmt::Write as _, fs, path::Path};

fn actions(out: &mut String, acts: &[CodeAction]) {
    for a in acts {
        if a.action_kind == 7 {
            let _ = writeln!(out, "{}", a.param_strings[0]);
        } else {
            let p: Vec<String> = a.param_strings[..a.param_count].iter().map(|s| s.to_string()).collect();
            let _ = writeln!(out, "// action lib{} id{} kind{} {} applies{} rel{} ({})",
                a.lib_id, a.id, a.action_kind, a.fn_name, a.applies_to, a.is_relative, p.join(" | "));
        }
    }
}

fn clean(s: &str) -> String { s.chars().map(|c| if c.is_alphanumeric() || c == '_' { c } else { '_' }).collect() }

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (exe, outdir) = (&args[1], Path::new(&args[2]));
    fs::create_dir_all(outdir.join("code")).unwrap();
    let data = fs::read(exe).unwrap();
    let g = gm8exe::reader::from_exe(data, Some(|s: &str| eprintln!("{}", s)), false, true).expect("read");
    let mut s = String::new();
    let st = &g.settings;
    let _ = writeln!(s, "version {:?} fullscreen {} scaling {} interpolate {} cursor {} esc_close {} f4 {} f5f6 {} freeze_on_lose_focus {}",
        g.version, st.fullscreen, st.scaling, st.interpolate_pixels, st.display_cursor, st.esc_close_game, st.f4_fullscreen_toggle, st.f5_save_f6_load, st.freeze_on_lose_focus);
    let c = |n: usize| n;
    let _ = writeln!(s, "counts sprites {} sounds {} backgrounds {} scripts {} fonts {} timelines {} objects {} rooms {} included {} extensions {}",
        c(g.sprites.iter().flatten().count()), g.sounds.iter().flatten().count(), g.backgrounds.iter().flatten().count(),
        g.scripts.iter().flatten().count(), g.fonts.iter().flatten().count(), g.timelines.iter().flatten().count(),
        g.objects.iter().flatten().count(), g.rooms.iter().flatten().count(), g.included_files.len(), g.extensions.len());
    for e in &g.extensions {
        let _ = writeln!(s, "EXTENSION {} folder {}", e.name, e.folder_name);
        for f in &e.files {
            let fns: Vec<String> = f.functions.iter().map(|x| format!("{}->{}", x.name, x.external_name)).collect();
            let _ = writeln!(s, "  file {} bytes {} fns {}", f.name, f.contents.len(), fns.join(", "));
        }
    }
    for f in &g.included_files {
        let _ = writeln!(s, "INCLUDED {} ({}) exists {} len {}", f.file_name, f.source_path, f.data_exists, f.source_length);
    }
    for (i, x) in g.sounds.iter().enumerate() {
        if let Some(x) = x {
            let _ = writeln!(s, "SOUND {} {} ext {} kind {} bytes {} vol {}", i, x.name, x.extension, x.kind as u32,
                x.data.as_ref().map(|d| d.len()).unwrap_or(0), x.volume);
        }
    }
    let order: Vec<String> = g.room_order.iter().map(|i| i.to_string()).collect();
    let _ = writeln!(s, "ROOM ORDER {}", order.join(" "));
    for (i, r) in g.rooms.iter().enumerate() {
        if let Some(r) = r {
            let views: Vec<String> = r.views.iter().filter(|v| v.visible).map(|v| format!("{}x{}@{}x{}", v.source_w, v.source_h, v.port_w, v.port_h)).collect();
            let _ = writeln!(s, "ROOM {} {} {}x{} speed {} views {} [{}] inst {}", i, r.name, r.width, r.height, r.speed, r.views_enabled, views.join(" "), r.instances.len());
            for inst in &r.instances {
                let oname = g.objects.get(inst.object as usize).and_then(|o| o.as_ref()).map(|o| o.name.to_string()).unwrap_or_default();
                let _ = writeln!(s, "  INST room {} obj {} {} at {},{}", i, inst.object, oname, inst.x, inst.y);
            }
            let mut code = r.creation_code.to_string();
            for inst in &r.instances {
                let cc = inst.creation_code.to_string();
                if !cc.trim().is_empty() { let _ = write!(code, "\n// instance {} obj {}\n{}", inst.id, inst.object, cc); }
            }
            if !code.trim().is_empty() { fs::write(outdir.join("code").join(format!("room_{}_{}.gml", i, clean(&r.name.to_string()))), code).unwrap(); }
        }
    }
    for (i, x) in g.scripts.iter().enumerate() {
        if let Some(x) = x { fs::write(outdir.join("code").join(format!("scr_{}_{}.gml", i, clean(&x.name.to_string()))), x.source.to_string()).unwrap(); }
    }
    for (i, x) in g.timelines.iter().enumerate() {
        if let Some(x) = x {
            let mut o = String::new();
            for (t, acts) in &x.moments { let _ = writeln!(o, "// ===== moment {}", t); actions(&mut o, acts); }
            fs::write(outdir.join("code").join(format!("tl_{}_{}.gml", i, clean(&x.name.to_string()))), o).unwrap();
        }
    }
    for (i, x) in g.objects.iter().enumerate() {
        if let Some(x) = x {
            let mut o = format!("// object {} sprite {} parent {} depth {} persistent {}\n", x.name, x.sprite_index, x.parent_index, x.depth, x.persistent);
            for (ty, evs) in x.events.iter().enumerate() {
                for (num, acts) in evs { let _ = writeln!(o, "// ===== event type {} num {}", ty, num); actions(&mut o, acts); }
            }
            fs::write(outdir.join("code").join(format!("obj_{}_{}.gml", i, clean(&x.name.to_string()))), o).unwrap();
        }
    }
    for (i, x) in g.sprites.iter().enumerate() {
        if let Some(x) = x { let _ = writeln!(s, "SPRITE {} {} frames {} {}x{}", i, x.name, x.frames.len(), x.frames.first().map(|f| f.width).unwrap_or(0), x.frames.first().map(|f| f.height).unwrap_or(0)); }
    }
    if let Some(ico) = &g.ico_file_raw {
        fs::write(outdir.join("icon.ico"), ico).unwrap();
    }
    fs::write(outdir.join("summary.txt"), s).unwrap();
}
