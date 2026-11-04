#!/usr/bin/env python3
"""Genera la capa en castellano del SRD (assets/srd/<edición>/es.json).

Fuente del texto: la traducción oficial al castellano del SRD 5.1 y del
SRD 5.2.1 (Wizards of the Coast, CC BY 4.0), recopilada en Markdown por
La Taberna de Eme (https://github.com/CarlosEmerito/latabernadeeme, CC BY 4.0).

Los ficheros en castellano no llevan el nombre inglés, así que cada entrada
se empareja con la inglesa por datos que no dependen del idioma:
  - criaturas: puntuaciones de característica, PG, CA y VD;
  - conjuros: nivel, escuela, clases, componentes y las tiradas de dados del texto;
  - objetos: rareza, precio, peso y las tiradas del texto;
y, como pista, por los nombres de la traducción de Foundry VTT de ravanno
(MIT) cuando se le pasa su carpeta.

Uso:
  git clone --depth 1 https://github.com/CarlosEmerito/latabernadeeme /tmp/taberna
  git clone --depth 1 https://github.com/ravanno/ravanno-dnd5e-es /tmp/ravanno   # opcional
  python3 tool/build_srd_es.py /tmp/taberna/data [/tmp/ravanno]
"""
import json
import os
import re
import sys
import unicodedata
from collections import Counter

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ---------------------------------------------------------------- utilidades

def norm(s):
    s = unicodedata.normalize('NFD', s or '').encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', ' ', s).strip()


def read_md(path):
    raw = open(path, encoding='utf-8').read()
    m = re.match(r'^---\n(.*?)\n---\n?(.*)$', raw, re.S)
    if not m:
        return {}, raw.strip()
    meta = yaml.safe_load(m.group(1)) or {}
    return meta, m.group(2).strip()


def load_dir(base, sub):
    d = os.path.join(base, sub)
    out = []
    if not os.path.isdir(d):
        return out
    for f in sorted(os.listdir(d)):
        if f.endswith('.md'):
            meta, body = read_md(os.path.join(d, f))
            meta['_slug'] = f[:-3]
            meta['_body'] = body
            out.append(meta)
    return out


DICE = re.compile(r'(\d+)\s*d\s*(\d+)')


def dice(text):
    return Counter(f'{a}d{b}' for a, b in DICE.findall(text or ''))


def jaccard(a, b):
    if not a and not b:
        return 1.0
    inter = sum((a & b).values())
    union = sum((a | b).values())
    return inter / union if union else 0.0


def numbers(text):
    return Counter(re.findall(r'\b\d+\b', text or ''))


def strip_md(s):
    return s.strip()


def assign(pairs, en_ids, es_ids, minimum):
    """Emparejamiento voraz por puntuación: cada entrada una sola vez."""
    pairs.sort(key=lambda p: -p[0])
    used_en, used_es, result = set(), set(), {}
    for score, e, s in pairs:
        if score < minimum or e in used_en or s in used_es:
            continue
        used_en.add(e)
        used_es.add(s)
        result[e] = s
    return result


SCHOOLS = {
    'abjuration': 'abjuracion', 'conjuration': 'conjuracion', 'divination': 'adivinacion',
    'enchantment': 'encantamiento', 'evocation': 'evocacion', 'illusion': 'ilusionismo',
    'necromancy': 'nigromancia', 'transmutation': 'transmutacion',
}
CLASSES = {
    'barbarian': 'barbaro', 'bard': 'bardo', 'cleric': 'clerigo', 'druid': 'druida', 'fighter': 'guerrero',
    'monk': 'monje', 'paladin': 'paladin', 'ranger': 'explorador', 'rogue': 'picaro', 'sorcerer': 'hechicero',
    'warlock': 'brujo', 'wizard': 'mago',
}
CLASS_NAMES = {
    'barbarian': 'Bárbaro', 'bard': 'Bardo', 'cleric': 'Clérigo', 'druid': 'Druida', 'fighter': 'Guerrero',
    'monk': 'Monje', 'paladin': 'Paladín', 'ranger': 'Explorador', 'rogue': 'Pícaro', 'sorcerer': 'Hechicero',
    'warlock': 'Brujo', 'wizard': 'Mago',
}
RARITY = {
    'common': 'comun', 'uncommon': 'poco comun', 'rare': 'raro', 'very rare': 'muy raro',
    'legendary': 'legendario', 'artifact': 'artefacto', 'varies': 'varia',
}


def rarity_key(s):
    n = norm(s)
    for k in ('muy rar', 'poco comun', 'infrecuente', 'comun', 'rar', 'legendari', 'artefacto', 'vari'):
        if k in n:
            return {'muy rar': 'muy raro', 'infrecuente': 'poco comun', 'rar': 'raro', 'legendari': 'legendario',
                    'vari': 'varia'}.get(k, k)
    return n


# ---------------------------------------------------------------- pistas de nombre

def foundry_hints(ravanno):
    """Nombre inglés normalizado -> nombre español normalizado (Foundry, SRD 5.1)."""
    hints = {}
    if not ravanno:
        return hints
    comp = os.path.join(ravanno, 'compendium')
    for f in ('dnd5e.items.json', 'dnd5e.monsters.json', 'dnd5e.tradegoods.json'):
        p = os.path.join(comp, f)
        if os.path.exists(p):
            for en, v in json.load(open(p, encoding='utf-8')).get('entries', {}).items():
                if isinstance(v, dict) and v.get('name'):
                    hints[norm(en)] = norm(v['name'])
    return hints


# Nombres de conjuros (traducción oficial) para los casos que los datos no resuelven solos.
SPELL_HINTS = {
    'magic missile': 'proyectil magico', 'fireball': 'bola de fuego', 'cure wounds': 'curar heridas',
    'healing word': 'palabra de curacion', 'shield': 'escudo', 'mage hand': 'mano de mago',
    'fire bolt': 'descarga de fuego', 'detect magic': 'detectar magia', 'light': 'luz',
    'prestidigitation': 'prestidigitacion', 'sacred flame': 'llama sagrada', 'guidance': 'guia',
    'thaumaturgy': 'taumaturgia', 'druidcraft': 'druidismo', 'minor illusion': 'ilusion menor',
    'message': 'mensaje', 'mending': 'reparar', 'resistance': 'resistencia', 'spare the dying': 'piedad con los moribundos',
    'shocking grasp': 'agarre electrizante', 'ray of frost': 'rayo de escarcha', 'poison spray': 'rociada venenosa',
    'eldritch blast': 'descarga sobrenatural', 'vicious mockery': 'burla danina', 'true strike': 'golpe certero',
    'produce flame': 'crear llama', 'shillelagh': 'garrote', 'dancing lights': 'luces danzantes',
    'chill touch': 'toque helado', 'acid splash': 'salpicadura acida',
}


# ---------------------------------------------------------------- conjuros

def match_spells(en, es):
    hints = {}
    for e in en:
        h = SPELL_HINTS.get(norm(e['name']))
        if h:
            hints[e['id']] = h
    pairs = []
    for e in en:
        school = SCHOOLS.get(norm(e['school']), '')
        ecls = {CLASSES.get(norm(c), norm(c)) for c in e.get('classes', [])}
        edice = dice(e.get('desc', '') + ' ' + e.get('higher', ''))
        ecomp = set(re.findall(r'\b[VSM]\b', e.get('components', '')))
        for s in es:
            if int(s.get('level', -1)) != e['level']:
                continue
            scls = {norm(c) for c in s.get('classes') or []}
            score = 3.0 if norm(s.get('school', '')) == school else 0.0
            score += 2 * (len(ecls & scls) / len(ecls | scls) if ecls | scls else 1)
            score += 1 if bool(s.get('ritual')) == e['ritual'] else -1
            score += 1 if bool(s.get('concentration')) == e['conc'] else -1
            scomp = set(re.findall(r'\b[VSM]\b', str(s.get('components', '')).split('(')[0]))
            score += 1 if scomp == ecomp else 0
            score += 3 * jaccard(edice, dice(s['_body']))
            le, ls = len(e.get('desc', '')), len(s['_body'])
            score += 1 - min(1, abs(le - ls) / max(le, ls, 1))
            if hints.get(e['id']) == norm(s['name']):
                score += 20
            pairs.append((score, e['id'], s['_slug']))
    return assign(pairs, None, None, 5.5)


def split_higher(body):
    """Separa «A niveles superiores» / «Con un espacio de conjuro de nivel superior» / «Mejora de truco»."""
    m = re.search(r'\n## A niveles superiores\n+', body)
    if m:
        return body[:m.start()].strip(), body[m.end():].strip()
    m = re.search(r'\n\n(?:\*\*)?(Con un espacio de conjuro de nivel superior\.|Mejora de truco\.)(?:\*\*)?\s*', body)
    if m:
        return body[:m.start()].strip(), body[m.end():].strip()
    return body.strip(), ''


def spell_overlay(s):
    desc, higher = split_higher(s['_body'])
    comp = str(s.get('components', ''))
    material = ''
    m = re.match(r'^(.*?)\s*\((.*)\)\s*$', comp)
    if m:
        comp, material = m.group(1), m.group(2)
    return {
        'name': s['name'], 'school': s.get('school', ''), 'time': s.get('castingTime', ''),
        'range': s.get('range', ''), 'components': comp, 'material': material,
        'duration': s.get('duration', ''), 'classes': s.get('classes') or [], 'desc': desc, 'higher': higher,
    }


# ---------------------------------------------------------------- criaturas

def first_int(s):
    m = re.search(r'\d+', str(s or ''))
    return int(m.group()) if m else -1


def cr_value(s):
    s = str(s or '').strip()
    if '/' in s:
        a, b = s.split('/', 1)
        return round(int(a) / int(b), 3)
    try:
        return float(s)
    except ValueError:
        return -1


def match_monsters(en, es, hints):
    pairs = []
    for e in en:
        eab = tuple(e['abilities'])
        en_hint = hints.get(norm(e['name']))
        for s in es:
            ab = s.get('abilities') or {}
            sab = tuple(int(ab.get(k, 0) or 0) for k in ('fue', 'des', 'con', 'int', 'sab', 'car'))
            same = sum(1 for a, b in zip(eab, sab) if a == b)
            if same < 4:
                continue
            score = same
            score += 3 if first_int(s.get('hp')) == e['hp'] else 0
            score += 1 if first_int(s.get('ac')) == e['ac'] else 0
            score += 2 if abs(cr_value(s.get('cr')) - float(e['cr'])) < 0.01 else 0
            etext = ' '.join(x['d'] for k in ('traits', 'actions', 'reactions', 'legendary', 'bonus') for x in e.get(k, []))
            score += 2 * jaccard(dice(etext), dice(s['_body']))
            if en_hint and en_hint == norm(s['name']):
                score += 5
            pairs.append((score, e['id'], s['_slug']))
    return assign(pairs, None, None, 9)


SECTIONS = {
    'Rasgos': 'traits', 'Acciones': 'actions', 'Acciones adicionales': 'bonus',
    'Reacciones': 'reactions', 'Acciones legendarias': 'legendary',
}


def named_blocks(text):
    out = []
    for para in re.split(r'\n\s*\n', text.strip()):
        para = para.strip()
        if not para:
            continue
        m = re.match(r'^\*\*(.+?)\*\*\s*(.*)$', para, re.S)
        if m:
            out.append({'n': m.group(1).strip().rstrip('.'), 'd': m.group(2).strip()})
        elif out:
            out[-1]['d'] += '\n\n' + para
        else:
            out.append({'n': '', 'd': para})
    return out


def monster_overlay(s):
    body = s['_body']
    parts = re.split(r'^## (.+)$', body, flags=re.M)
    intro = parts[0].strip()
    o = {
        'name': s['name'], 'size': s.get('size', ''), 'type': (s.get('type') or '') + (f" ({s['tags']})" if s.get('tags') else ''),
        'alignment': s.get('alignment', ''), 'speed': s.get('speed', ''), 'saves': s.get('saves', ''),
        'skills': s.get('skills', ''), 'vuln': s.get('vulnerabilities', ''), 'res': s.get('resistances', ''),
        'imm': s.get('immunities', ''), 'condImm': s.get('conditionImmunities', ''), 'senses': s.get('senses', ''),
        'languages': s.get('languages', ''),
    }
    ac = str(s.get('ac', ''))
    m = re.match(r'^\s*\d+\s*\((.*)\)\s*$', ac)
    o['acNote'] = m.group(1) if m else ''
    for i in range(1, len(parts) - 1, 2):
        key = SECTIONS.get(parts[i].strip())
        if key:
            o[key] = named_blocks(parts[i + 1])
    if intro:
        o['desc'] = intro
    return o


# ---------------------------------------------------------------- objetos

def price_cp(s):
    s = norm(str(s or '')).replace(' ', '')
    m = re.match(r'^(\d+)(pc|pp|pe|po|ppt)$', s)
    if not m:
        return -1
    v = int(m.group(1))
    return v * {'pc': 1, 'pp': 10, 'pe': 50, 'po': 100, 'ppt': 1000}[m.group(2)]


def weight_kg(s):
    m = re.search(r'(\d+(?:,\d+)?)', str(s or ''))
    return float(m.group(1).replace(',', '.')) if m else -1


STOP = {'de', 'del', 'la', 'el', 'los', 'las', 'y', 'o', 'a', 'para', 'con', 'en', 'un', 'una', 'por'}


def tokens(s):
    return {t for t in norm(s).split() if t not in STOP and not t.isdigit()}


def name_sim(a, b):
    ta, tb = tokens(a), tokens(b)
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / min(len(ta), len(tb))


def en_variants(name):
    """«Crossbow, light (x)» -> también «light crossbow»."""
    out = [name]
    base = re.sub(r'\s*\(.*?\)', '', name).strip()
    if ', ' in base:
        a, b = base.split(', ', 1)
        out.append(f'{b} {a}')
    out.append(base)
    return out


def match_items(en, es_equip, es_magic, hints, manual):
    pairs = []
    by_name = {norm(s['name']): s for s in es_equip + es_magic}
    for e in en:
        hs = [hints.get(norm(v)) for v in en_variants(e['name'])]
        hs = [h for h in hs if h]
        forced = manual.get(e['name'])
        if forced is not None and norm(forced) not in by_name:
            forced = None
        if variant_name(e['name']) is not None:
            continue
        if e['cat'] == 'magic':
            erar = RARITY.get(norm(e.get('rarity', '')), norm(e.get('rarity', '')))
            for s in es_magic:
                score = 0.0
                if forced is not None:
                    score += 50 if norm(forced) == norm(s['name']) else -50
                if any(h == norm(s['name']) for h in hs):
                    score += 10
                elif hs:
                    score += 4 * max(name_sim(h, s['name']) for h in hs)
                srar = rarity_key(s.get('rarity', ''))
                score += 1 if srar == erar else 0
                score += 1 if bool(s.get('attunement')) == bool(e.get('attune')) else 0
                score += 3 * jaccard(dice(e.get('desc', '')), dice(s['_body']))
                score += 1 * jaccard(numbers(e.get('desc', '')), numbers(s['_body']))
                pairs.append((score, e['id'], 'o:' + s['_slug']))
        else:
            for s in es_equip:
                score = 0.0
                if forced is not None:
                    score += 50 if norm(forced) == norm(s['name']) else -50
                if any(h == norm(s['name']) for h in hs):
                    score += 10
                elif hs:
                    score += 5 * max(name_sim(h, s['name']) for h in hs)
                cp = price_cp(s.get('price'))
                score += 3 if cp >= 0 and cp == e.get('cost', -2) else 0
                kg = weight_kg(s.get('weight'))
                lb = e.get('weight', 0) or 0
                if kg >= 0 and lb > 0 and abs(kg - lb / 2) < 0.06 * max(1, lb):
                    score += 2
                elif kg < 0 and lb == 0:
                    score += 0.5
                pairs.append((score, e['id'], 'e:' + s['_slug']))
    return assign(pairs, None, None, 6.5)


PROPS = {
    'ammunition': 'munición', 'finesse': 'sutil', 'heavy': 'pesada', 'light': 'ligera', 'loading': 'recarga',
    'range': 'distancia', 'reach': 'alcance', 'special': 'especial', 'thrown': 'arrojadiza',
    'two-handed': 'a dos manos', 'versatile': 'versátil', 'monk': 'monje',
}
DAMAGE = {
    'acid': 'ácido', 'bludgeoning': 'contundente', 'cold': 'frío', 'fire': 'fuego', 'force': 'fuerza',
    'lightning': 'relámpago', 'necrotic': 'necrótico', 'piercing': 'perforante', 'poison': 'veneno',
    'psychic': 'psíquico', 'radiant': 'radiante', 'slashing': 'cortante', 'thunder': 'trueno',
}
MASTERY = {
    'cleave': 'hendir', 'graze': 'rozar', 'nick': 'mellar', 'push': 'empujar', 'sap': 'debilitar',
    'slow': 'ralentizar', 'topple': 'derribar', 'vex': 'molestar',
}
SUBCATS = {
    'simple melee': 'Cuerpo a cuerpo sencilla', 'simple ranged': 'A distancia sencilla',
    'martial melee': 'Cuerpo a cuerpo marcial', 'martial ranged': 'A distancia marcial',
    'light': 'Ligera', 'medium': 'Intermedia', 'heavy': 'Pesada', 'shield': 'Escudo',
    'standard gear': 'Equipo de aventurero', 'adventuring gear': 'Equipo de aventurero', 'ammunition': 'Munición',
    'arcane foci': 'Canalizador arcano', 'arcane focus': 'Canalizador arcano', 'druidic foci': 'Canalizador druídico',
    'druidic focus': 'Canalizador druídico', 'holy symbols': 'Símbolo sagrado', 'holy symbol': 'Símbolo sagrado',
    'equipment packs': 'Paquete de equipo', 'kits': 'Útiles', 'artisan s tools': 'Herramientas de artesano',
    'gaming sets': 'Juego', 'musical instrument': 'Instrumento musical', 'other tools': 'Otras herramientas',
    'mounts and other animals': 'Monturas y otros animales', 'tack harness and drawn vehicles': 'Arreos y vehículos',
    'waterborne vehicles': 'Vehículos acuáticos', 'tools': 'Herramientas', 'mounts and vehicles': 'Monturas y vehículos',
}


def tr_damage(s):
    def rep(m):
        w = m.group(0)
        t = DAMAGE.get(w.lower())
        return t if t else w
    return re.sub(r'[A-Za-z]+', rep, s or '')


def tr_props(props):
    out = []
    for p in props:
        n = norm(p)
        out.append(PROPS.get(n, PROPS.get(n.replace(' ', '-'), p)).capitalize() if n in PROPS or n.replace(' ', '-') in PROPS else p)
    return out


def strip_item_header(body):
    # «Objeto maravilloso, infrecuente Mientras…»: la cabecera del PDF va pegada al texto.
    return re.sub(r'^(?:Objeto maravilloso|Arma|Armadura|Anillo|Poción|Pergamino|Varita|Vara|Bastón|Cetro)'
                  r'[^.\n]{0,120}?(?:común|infrecuente|poco común|rar[oa]|muy rar[oa]|legendari[oa]|artefacto|'
                  r'rareza variable|rareza según[^)]*|varía)(?:\s*\([^)]*\))?\s+(?=[A-ZÁÉÍÓÚÑ¿¡])', '', body.strip())


GIANTS = {'Hill': 'de las colinas', 'Stone': 'de piedra', 'Frost': 'de escarcha', 'Fire': 'de fuego',
          'Cloud': 'de las nubes', 'Storm': 'de las tormentas'}
DMG_ES = {'Acid': 'ácido', 'Cold': 'frío', 'Fire': 'fuego', 'Force': 'fuerza', 'Lightning': 'relámpago',
          'Necrotic': 'necrótico', 'Poison': 'veneno', 'Psychic': 'psíquico', 'Radiant': 'radiante', 'Thunder': 'trueno'}
ELEMENTS = {'Air': 'aire', 'Earth': 'tierra', 'Fire': 'fuego', 'Water': 'agua'}
COLORS = {'Black': 'negro', 'Blue': 'azul', 'Brass': 'de latón', 'Bronze': 'de bronce', 'Copper': 'de cobre',
          'Gold': 'de oro', 'Green': 'verde', 'Red': 'rojo', 'Silver': 'de plata', 'White': 'blanco'}
FEET_M = {'3': '0,9', '4': '1,2', '5': '1,5', '6': '1,8', '7': '2,1', '9': '2,7'}
IOUN = {'Absorption': 'absorción', 'Agility': 'agilidad', 'Awareness': 'consciencia', 'Fortitude': 'fortaleza',
        'Greater Absorption': 'absorción mayor', 'Insight': 'perspicacia', 'Intellect': 'intelecto',
        'Leadership': 'liderazgo', 'Mastery': 'maestría', 'Protection': 'protección', 'Regeneration': 'regeneración',
        'Reserve': 'reserva', 'Strength': 'fuerza', 'Sustenance': 'sustento'}
FIGURINES = {'Bronze Griffon': 'grifo de bronce', 'Ebony Fly': 'mosca de ébano', 'Golden Lions': 'leones dorados',
             'Ivory Goats': 'cabras de marfil', 'Marble Elephant': 'elefante de mármol',
             'Obsidian Steed': 'corcel de obsidiana', 'Onyx Dog': 'perro de ónice', 'Serpentine Owl': 'búho serpentino',
             'Silver Raven': 'cuervo de plata'}
FEATHERS = {'Anchor': 'ancla', 'Bird': 'pájaro', 'Fan': 'abanico', 'Swan Boat': 'bote cisne', 'Tree': 'árbol',
            'Whip': 'látigo'}
SCROLL = {'Cantrip': 'truco', '1st': 'nivel 1', '2nd': 'nivel 2', '3rd': 'nivel 3', '4th': 'nivel 4',
          '5th': 'nivel 5', '6th': 'nivel 6', '7th': 'nivel 7', '8th': 'nivel 8', '9th': 'nivel 9'}
PLUS = {'Ammunition': 'Munición', 'Armor': 'Armadura', 'Weapon': 'Arma', 'Shield': 'Escudo'}
PLUS_BASE = {'Ammunition': 'Munición +1, +2 o +3', 'Armor': 'Armadura +1, +2 o +3', 'Weapon': 'Arma +1, +2 o +3',
             'Shield': 'Escudo +1, +2 o +3'}


def variant_name(name):
    """Variantes que el SRD en castellano agrupa en una sola entrada: (nombre, entrada base)."""
    rules = [
        (r'^(Ammunition|Armor|Weapon|Shield),? \+(\d)$', lambda m: (f'{PLUS[m[1]]} +{m[2]}', PLUS_BASE[m[1]])),
        (r'^Wand of the War Mage,? \+(\d)$', lambda m: (f'Varita del mago de guerra +{m[1]}',
                                                       'Varita del mago de guerra +1, +2 o +3')),
        (r'^(Gray|Rust|Tan) Bag of Tricks$', lambda m: (
            'Bolsa de trucos ' + {'Gray': 'gris', 'Rust': 'color óxido', 'Tan': 'parda'}[m[1]], 'Bolsa de trucos')),
        (r'^Belt of (\w+) Giant Strength$', lambda m: (f'Cinturón de fuerza de gigante {GIANTS[m[1]]}',
                                                      'Cinturón de fuerza de gigante')),
        (r'^Potion of (\w+) Giant Strength$', lambda m: (f'Poción de fuerza de gigante {GIANTS[m[1]]}',
                                                        'Poción de fuerza de gigante')),
        (r'^Carpet of Flying \((\d) ft\. × (\d) ft\.\)$', lambda m: (
            f'Alfombra voladora ({FEET_M[m[1]]} × {FEET_M[m[2]]} m)', 'Alfombra voladora')),
        (r'^Crystal Ball of (Mind Reading|Telepathy|True Seeing)$', lambda m: (
            {'Mind Reading': 'Bola de cristal de leer mentes', 'Telepathy': 'Bola de cristal de telepatía',
             'True Seeing': 'Bola de cristal de visión veraz'}[m[1]], 'Bola de cristal')),
        (r'^(\w+) Dragon Scale Mail$', lambda m: (f'Cota de escamas de dragón {COLORS[m[1]]}',
                                                 'Cota de escamas de dragón')),
        (r'^(Air|Earth|Fire|Water) Elemental Gem$', lambda m: (f'Gema elemental ({ELEMENTS[m[1]]})', 'Gema elemental')),
        (r'^(.+) Feather Token$', lambda m: (f'Ficha de pluma ({FEATHERS[m[1]]})', 'Ficha de pluma')),
        (r'^(.+) Figurine of Wondrous Power$', lambda m: (
            f'Estatuilla de poder maravilloso ({FIGURINES[m[1]]})', 'Estatuilla de poder maravilloso')),
        (r'^(Silver|Brass|Bronze|Iron) Horn of Valhalla$', lambda m: (
            'Cuerno del Valhalla ' + {'Silver': 'de plata', 'Brass': 'de latón', 'Bronze': 'de bronce',
                                      'Iron': 'de hierro'}[m[1]], 'Cuerno del Valhalla')),
        (r'^Ioun Stone of (.+)$', lambda m: (f'Piedra Ioun ({IOUN[m[1]]})', 'Piedra Ioun')),
        (r'^Manual of (Clay|Flesh|Iron|Stone) Golems$', lambda m: (
            'Manual de gólems ' + {'Clay': 'de arcilla', 'Flesh': 'de carne', 'Iron': 'de hierro',
                                   'Stone': 'de piedra'}[m[1]], 'Manual de gólems')),
        (r'^Potion of (Greater|Superior|Supreme) Healing$', lambda m: (
            'Poción de curación ' + {'Greater': 'mayor', 'Superior': 'superior', 'Supreme': 'suprema'}[m[1]],
            'Poción de curación|Pociones de curación')),
        (r'^Potion of (\w+) Resistance$', lambda m: (f'Poción de resistencia ({DMG_ES[m[1]]})', 'Poción de resistencia')),
        (r'^Ring of (\w+) Resistance$', lambda m: (f'Anillo de resistencia ({DMG_ES[m[1]]})', 'Anillo de resistencia')),
        (r'^Ring of (Air|Earth|Fire|Water) Elemental Command$', lambda m: (
            f'Anillo de comandar elementales ({ELEMENTS[m[1]]})', 'Anillo de comandar elementales')),
        (r'^Spell Scroll \((.+)\)$', lambda m: (f'Pergamino de conjuro ({SCROLL[m[1]]})', 'Pergamino de conjuro')),
    ]
    for rx, fn in rules:
        m = re.match(rx, name)
        if m:
            try:
                return fn(m)
            except KeyError:
                return None
    return None


MAGIC_BASE = {
    'Adamantine Armor': 'Armadura adamantina', 'Ammunition, +1, +2, or +3': 'Munición +1, +2 o +3',
    'Ammunition': 'Munición +1, +2 o +3', 'Ammunition of Slaying': 'Munición asesina',
    'Apparatus of the Crab': 'Aparato del crustáceo', 'Armor, +1, +2, or +3': 'Armadura +1, +2 o +3',
    'Armor': 'Armadura +1, +2 o +3', 'Armor of Resistance': 'Armadura de resistencia', 'Bag of Tricks': 'Bolsa de trucos',
    'Belt of Giant Strength': 'Cinturón de fuerza de gigante', 'Berserker Axe': 'Hacha berserker',
    'Carpet of Flying': 'Alfombra voladora', 'Cloak of the Manta Ray': 'Capa de la mantarraya',
    'Crystal Ball': 'Bola de cristal', 'Dancing Sword': 'Espada danzarina', 'Defender': 'Defensora',
    'Dragon Scale Mail': 'Cota de escamas de dragón', 'Dragon Slayer': 'Matadragones',
    'Efficient Quiver': 'Aljaba eficiente', 'Elemental Gem': 'Gema elemental', 'Feather Token': 'Ficha de pluma',
    'Figurine of Wondrous Power': 'Estatuilla de poder maravilloso', 'Flame Tongue': 'Lengua de fuego',
    'Frost Brand': 'Hierro de escarcha', 'Giant Slayer': 'Matagigantes',
    'Glamoured Studded Leather Armor': 'Cuero tachonado encantado', 'Glamoured Studded Leather': 'Cuero tachonado encantado',
    'Holy Avenger': 'Vengadora sagrada', 'Horn of Valhalla': 'Cuerno del Valhalla',
    'Horseshoes of a Zephyr': 'Herraduras del céfiro', 'Ioun Stone': 'Piedra Ioun',
    'Iron Bands of Binding': 'Bandas de hierro inmovilizadoras', 'Iron Bands': 'Bandas de hierro',
    'Luck Blade': 'Filo de la fortuna', 'Manual of Golems': 'Manual de gólems', 'Mithral Armor': 'Armadura de mithral',
    'Nine Lives Stealer': 'Ladrona de nueve vidas', 'Periapt of Health': 'Talismán de salud',
    'Potion of Giant Strength': 'Poción de fuerza de gigante', 'Potion of Healing': 'Poción de curación',
    'Potions of Healing': 'Pociones de curación', 'Potion of Resistance': 'Poción de resistencia',
    'Restorative Ointment': 'Ungüento reparador', 'Ring of Elemental Command': 'Anillo de comandar elementales',
    'Ring of Resistance': 'Anillo de resistencia', 'Spell Scroll': 'Pergamino de conjuro',
    'Stone of Controlling Earth Elementals': 'Piedra de controlar elementales de tierra',
    'Stone of Good Luck (Luckstone)': 'Piedra de la buena fortuna (piedra de la suerte)',
    'Sword of Life Stealing': 'Espada ladrona de vida', 'Sword of Sharpness': 'Espada de hoja afilada',
    'Sword of Wounding': 'Espada hiriente', 'Vicious Weapon': 'Arma feroz', 'Vorpal Sword': 'Espada vorpal',
    'Wand of the War Mage, +1, +2, or +3': 'Varita del mago de guerra +1, +2 o +3',
    'Wand of the War Mage': 'Varita del mago de guerra +1, +2 o +3', 'Weapon, +1, +2, or +3': 'Arma +1, +2 o +3',
    'Weapon': 'Arma +1, +2 o +3', 'Shield': 'Escudo +1, +2 o +3', 'Dragon Orb': 'Orbe Dragontino',
    'Mysterious Deck': 'Baraja misteriosa', 'Weapon of Warning': 'Arma de advertencia', 'Crystal Ball of Mind Reading': 'Bola de cristal de leer mentes',
    'Crystal Ball of Telepathy': 'Bola de cristal de telepatía', 'Crystal Ball of True Seeing': 'Bola de cristal de visión veraz',
}

# Equipo: nombre oficial cuando existe en el SRD en castellano; si no, traducción del nombre.
EQUIP_ES = {
    'Flail': 'Mangual', 'Alms box': 'Caja para limosnas', 'Arrow': 'Flechas (20)', 'Block of incense': 'Bloque de incienso',
    'Censer': 'Incensario', "Clothes, traveler's": 'Ropas de viaje', 'Flask or tankard': 'Frasco o jarra',
    'Hammer, sledge': 'Mazo', 'Holy water (flask)': 'Agua bendita (frasco)', 'Ink (1 ounce bottle)': 'Tinta (frasco de 30 ml)',
    'Jug or pitcher': 'Jarro o cántaro', 'Little bag of sand': 'Bolsita de arena', 'Mirror, steel': 'Espejito de acero',
    'Rope, hempen (50 feet)': 'Cuerda de cáñamo (15 m)', 'Rope, silk (50 feet)': 'Cuerda de seda (15 m)',
    'Small knife': 'Cuchillo pequeño', 'String (10 feet)': 'Cordel (3 m)', 'Vestments': 'Vestiduras',
    'Playing Card Set': 'Naipes', 'Donkey': 'Burro', 'Barding: Padded': 'Barda acolchada', 'Barding: Leather': 'Barda de cuero',
    'Barding: Studded Leather': 'Barda de cuero tachonado', 'Barding: Hide': 'Barda de pieles',
    'Barding: Chain shirt': 'Barda de camisa de malla', 'Barding: Scale mail': 'Barda de cota de escamas',
    'Barding: Breastplate': 'Barda de coraza', 'Barding: Half plate': 'Barda de media armadura',
    'Barding: Ring mail': 'Barda de cota guarnecida', 'Barding: Chain mail': 'Barda de cota de malla',
    'Barding: Splint': 'Barda de bandas', 'Barding: Plate': 'Barda de placas', 'Bit and bridle': 'Bocado y bridas',
    'Carriage': 'Carruaje', 'Cart': 'Carreta', 'Chariot': 'Carro de guerra', 'Wagon': 'Carro',
    'Animal Feed (1 day)': 'Alimento (por día)', 'Sled': 'Trineo', 'Stabling (1 day)': 'Estabulado (por día)',
    'Galley': 'Galera', 'Keelboat': 'Barcaza', 'Longship': 'Drakkar', 'Rowboat': 'Bote de remos',
    'Sailing ship': 'Velero', 'Warship': 'Navío de guerra',
    'Acid': 'Ácido', 'Arrows': 'Flechas (20)', 'Bagpipes': 'Gaita', 'Bolts': 'Virotes (20)',
    'Bullets, Firearm': 'Balas de arma de fuego (10)', 'Bullets, Sling': 'Proyectiles de honda (20)',
    'Case, Map or Scroll': 'Estuche para mapas o pergaminos', 'Chain': 'Cadena', "Clothes, Traveler's": 'Ropas de viaje',
    'Costume': 'Disfraz', 'Dice': 'Dados', 'Dragonchess': 'Ajedrez de dragones', 'Drum': 'Tambor', 'Dulcimer': 'Dulcémele',
    'Flute': 'Flauta', "Glassblower's Tools": 'Herramientas de soplador de vidrio', 'Holy Water': 'Agua bendita',
    'Horn': 'Cuerno', 'Ink': 'Tinta', 'Ladder': 'Escalera', 'Lute': 'Laúd', 'Lyre': 'Lira', 'Map': 'Mapa',
    'Mirror': 'Espejo', 'Musket': 'Mosquete', 'Needles': 'Dardos (50)', 'Oil': 'Aceite', 'Pan flute': 'Flauta de pan',
    'Pistol': 'Pistola', 'Playing Cards': 'Naipes', 'Robe': 'Túnica', 'Rope': 'Cuerda', 'Shawm': 'Chirimía',
    'Spellbook': 'Libro de conjuros', 'Spell Scroll, Level 1': 'Pergamino de conjuro (nivel 1)',
    'Spikes, Iron': 'Puntas de hierro', 'String': 'Cordel', 'Tent': 'Tienda',
    'Three-Dragon Ante': 'Apuesta de los tres dragones', 'Viol': 'Viola',
}
ITEM_NAMES = {**EQUIP_ES, **MAGIC_BASE}

MONSTER_FORMS = {
    'Bat Form': 'forma de murciélago', 'Mist Form': 'forma de niebla', 'Bear Form': 'forma de oso',
    'Human Form': 'forma humana', 'Boar Form': 'forma de jabalí', 'Rat Form': 'forma de rata',
    'Tiger Form': 'forma de tigre', 'Hybrid Form': 'forma híbrida', 'Wolf Form': 'forma de lobo',
}
MONSTER_BASE = {
    'Vampire': 'Vampiro', 'Werebear': 'Hombre oso', 'Wereboar': 'Hombre jabalí', 'Wererat': 'Hombre rata',
    'Weretiger': 'Hombre tigre', 'Werewolf': 'Hombre lobo',
}
MONSTER_VARIANTS = {
    'Giant Rat (Diseased)': ('Giant Rat', 'enferma'), 'Swarm of Beetles': ('Swarm of Insects', 'escarabajos'),
    'Swarm of Centipedes': ('Swarm of Insects', 'ciempiés'), 'Swarm of Spiders': ('Swarm of Insects', 'arañas'),
    'Swarm of Wasps': ('Swarm of Insects', 'avispas'),
}


# ---------------------------------------------------------------- clases, listas y reglas

def class_overlay(meta):
    o = {'name': meta['name'], 'features': {}}
    body = meta['_body']
    m = re.search(r'## Progresión\n+(\|.*?)(?:\n\n|\Z)', body, re.S)
    if m:
        rows = [r for r in m.group(1).split('\n') if r.startswith('|')]
        header = [c.strip() for c in rows[0].strip('|').split('|')]
        fi = next((i for i, h in enumerate(header) if h.lower().startswith('rasgo')), None)
        if fi is not None:
            for r in rows[2:]:
                cells = [c.strip() for c in r.strip('|').split('|')]
                if len(cells) <= fi or not cells[0].isdigit():
                    continue
                feats = [f.strip() for f in cells[fi].split(',') if f.strip() and f.strip() not in ('—', '-')]
                o['features'][cells[0]] = feats
    return o


def rules_chapters(rules, edition):
    if edition == '2014':
        groups = [
            ('Estados', lambda m: m.get('category') == 'Condiciones' or m['_slug'].startswith('apendice')),
            ('Combate', lambda m: m['_slug'] in {
                'acciones-en-combate', 'atacar', 'cobertura', 'combate-bajo-el-agua', 'combate-montado',
                'dano-y-curacion', 'estructura-de-un-combate', 'movimiento-y-posicion'}),
            ('Conjuros', lambda m: m['_slug'] in {'lanzamiento-de-conjuros', 'lanzar-un-conjuro', 'que-es-un-conjuro'}),
            ('Características', lambda m: m['_slug'] in {
                'bonificador-por-competencia', 'pruebas-de-caracteristica', 'puntuaciones-de-caracteristica-y-modificadores',
                'tiradas-de-salvacion', 'usar-cada-caracteristica', 'uso-de-las-puntuaciones-de-caracteristica',
                'ventaja-y-desventaja'}),
        ]
    else:
        groups = [('Estados', lambda m: m.get('category') == 'Condiciones')]
    chapters, used = [], set()
    for title, pred in groups:
        secs = [m for m in rules if pred(m) and m['_slug'] not in used]
        used.update(m['_slug'] for m in secs)
        if secs:
            chapters.append((title, secs))
    rest = [m for m in rules if m['_slug'] not in used]
    if rest:
        chapters.append(('Aventura y reglas generales' if edition == '2014' else 'Glosario de reglas', rest))
    out = []
    for title, secs in chapters:
        out.append({
            'id': norm(title).replace(' ', '-'), 'name': title,
            'sections': [{'id': m['_slug'], 'name': m['name'], 'desc': m['_body']}
                         for m in sorted(secs, key=lambda m: norm(m['name']))],
        })
    return out


CONDITIONS = {
    'blinded': 'cegado', 'charmed': 'hechizado', 'deafened': 'ensordecido', 'exhaustion': 'cansancio',
    'frightened': 'asustado', 'grappled': 'agarrado', 'incapacitated': 'incapacitado', 'invisible': 'invisible',
    'paralyzed': 'paralizado', 'petrified': 'petrificado', 'poisoned': 'envenenado', 'prone': 'derribado',
    'restrained': 'apresado', 'stunned': 'aturdido', 'unconscious': 'inconsciente',
}

SPECIES = {
    'dragonborn': 'Dracónido', 'dwarf': 'Enano', 'elf': 'Elfo', 'gnome': 'Gnomo', 'half elf': 'Semielfo',
    'half orc': 'Semiorco', 'halfling': 'Mediano', 'human': 'Humano', 'tiefling': 'Tiefling', 'goliath': 'Goliat',
    'orc': 'Orco', 'aasimar': 'Aasimar',
}
SUBSPECIES = {
    'hill dwarf': 'Enano de las colinas', 'high elf': 'Alto elfo', 'lightfoot halfling': 'Mediano piesligeros',
    'rock gnome': 'Gnomo de las rocas', 'drow': 'Drow', 'wood elf': 'Elfo de los bosques',
    'forest gnome': 'Gnomo de los bosques', 'black dragon': 'Dragón negro', 'blue dragon': 'Dragón azul',
    'brass dragon': 'Dragón de latón', 'bronze dragon': 'Dragón de bronce', 'copper dragon': 'Dragón de cobre',
    'gold dragon': 'Dragón de oro', 'green dragon': 'Dragón verde', 'red dragon': 'Dragón rojo',
    'silver dragon': 'Dragón de plata', 'white dragon': 'Dragón blanco', 'cloud giant': 'Gigante de las nubes',
    'fire giant': 'Gigante de fuego', 'frost giant': 'Gigante de escarcha', 'hill giant': 'Gigante de las colinas',
    'stone giant': 'Gigante de piedra', 'storm giant': 'Gigante de las tormentas', 'abyssal': 'Abisal',
    'chthonic': 'Ctónico', 'infernal': 'Infernal',
}
LINEAGE_PREFIX = {
    'Draconic Ancestor': 'Linaje dracónico', 'Elven Lineage': 'Linaje élfico', 'Gnomish Lineage': 'Linaje gnomo',
    'Giant Ancestry': 'Linaje gigante', 'Fiendish Legacy': 'Legado infernal',
}
LINEAGE_OPTION = {
    'Black': 'dragón negro', 'Blue': 'dragón azul', 'Brass': 'dragón de oropel', 'Bronze': 'dragón de bronce',
    'Copper': 'dragón de cobre', 'Gold': 'dragón de oro', 'Green': 'dragón verde', 'Red': 'dragón rojo',
    'Silver': 'dragón de plata', 'White': 'dragón blanco', 'Drow': 'drow', 'High Elf': 'alto elfo',
    'Wood Elf': 'elfo de los bosques', 'Forest Gnome': 'gnomo de los bosques', 'Rock Gnome': 'gnomo de las rocas',
    "Cloud's Jaunt": 'salto de las nubes', "Fire's Burn": 'abrasión del fuego', "Frost's Chill": 'frío de la escarcha',
    "Hill's Tumble": 'caída de las colinas', "Stone's Endurance": 'resistencia de la piedra',
    "Storm's Thunder": 'trueno de la tormenta', 'Abyssal': 'abisal', 'Chthonic': 'ctónico', 'Infernal': 'infernal',
}


def subspecies_es(name):
    if ': ' in name:
        a, b = name.split(': ', 1)
        if a in LINEAGE_PREFIX:
            return f'{LINEAGE_PREFIX[a]}: {LINEAGE_OPTION.get(b, b)}'
    return SUBSPECIES.get(norm(name), name)


BACKGROUNDS = {'acolyte': 'Acólito', 'criminal': 'Criminal', 'sage': 'Erudito', 'soldier': 'Soldado'}
LANGUAGES = {
    'common': 'Común', 'dwarvish': 'Enano', 'elvish': 'Élfico', 'giant': 'Gigante', 'gnomish': 'Gnomo',
    'goblin': 'Goblin', 'halfling': 'Mediano', 'orc': 'Orco', 'abyssal': 'Abisal', 'celestial': 'Celestial',
    'draconic': 'Dracónico', 'deep speech': 'Habla de las profundidades', 'infernal': 'Infernal',
    'primordial': 'Primordial', 'sylvan': 'Silvano', 'undercommon': 'Infracomún', 'common sign language':
    'Lenguaje de signos común', 'druidic': 'Druídico', "thieves cant": 'Jerga de ladrones',
}
FEATS = {
    'grappler': 'apresador', 'alert': 'alerta', 'magic initiate': 'iniciado en la magia', 'savage attacker':
    'atacante salvaje', 'skilled': 'habilidoso', 'ability score improvement': 'mejora de caracteristica',
    'archery': 'tiro con arco', 'defense': 'defensa', 'great weapon fighting': 'combate con armas a dos manos',
    'two weapon fighting': 'combate con dos armas', 'boon of combat prowess': 'don de la pericia en combate',
    'boon of dimensional travel': 'don del viaje dimensional', 'boon of fate': 'don del destino',
    'boon of irresistible offense': 'don del ataque imparable', 'boon of spell recall': 'don del recuerdo de conjuros',
    'boon of the night spirit': 'don del espiritu de la noche', 'boon of truesight': 'don de la vision verdadera',
}


# ---------------------------------------------------------------- principal

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    data = sys.argv[1]
    hints = foundry_hints(sys.argv[2] if len(sys.argv) > 2 else None)
    for edition, folder in (('2014', 'ed51'), ('2024', 'ed52')):
        src = os.path.join(data, folder)
        en_dir = os.path.join(ROOT, 'assets', 'srd', edition)

        def en(name):
            return json.load(open(os.path.join(en_dir, name + '.json'), encoding='utf-8'))

        out = {}
        # Conjuros
        es_spells = load_dir(src, 'conjuros')
        en_spells = en('spells')
        m = match_spells(en_spells, es_spells)
        by = {s['_slug']: s for s in es_spells}
        out['spells'] = {k: spell_overlay(by[v]) for k, v in m.items()}
        report(edition, 'conjuros', en_spells, m, es_spells)
        # Criaturas
        es_mon = load_dir(src, 'monstruos')
        en_mon = en('monsters')
        m = match_monsters(en_mon, es_mon, hints)
        by = {s['_slug']: s for s in es_mon}
        out['monsters'] = {k: monster_overlay(by[v]) for k, v in m.items()}
        es_mon_by_name = {norm(x['name']): x for x in es_mon}
        en_by_name = {x['name']: x for x in en_mon}
        for x in en_mon:
            base, suffix = None, None
            if ', ' in x['name'] and x['name'].split(', ', 1)[1] in MONSTER_FORMS:
                b, f = x['name'].split(', ', 1)
                base, suffix = b, MONSTER_FORMS[f]
            elif x['name'] in MONSTER_VARIANTS:
                base, suffix = MONSTER_VARIANTS[x['name']]
            if base is None:
                continue
            o = out['monsters'].get(x['id'])
            if o is None:
                b = en_by_name.get(base)
                if b and b['id'] in out['monsters']:
                    o = dict(out['monsters'][b['id']])
                elif norm(MONSTER_BASE.get(base, '')) in es_mon_by_name:
                    o = monster_overlay(es_mon_by_name[norm(MONSTER_BASE[base])])
            if o is not None:
                o = dict(o)
                o['name'] = f"{MONSTER_BASE.get(base, o['name'])} ({suffix})"
                out['monsters'][x['id']] = o
        report(edition, 'criaturas', en_mon, {k: v for k, v in m.items()}, es_mon)
        print(f"   con variantes: {len(out['monsters'])}/{len(en_mon)}")
        # Objetos
        es_eq = load_dir(src, 'equipo')
        es_mg = load_dir(src, 'objetos')
        en_items = en('items')
        m = match_items(en_items, es_eq, es_mg, hints, ITEM_NAMES)
        by = {'e:' + s['_slug']: s for s in es_eq}
        by.update({'o:' + s['_slug']: s for s in es_mg})
        items = {}
        es_by_name = {norm(x['name']): x for x in es_eq + es_mg}
        for e in en_items:
            o = {}
            s = by.get(m.get(e['id'], ''))
            v = variant_name(e['name'])
            if v:
                o['name'] = v[0]
                s = next((es_by_name[norm(b)] for b in v[1].split('|') if norm(b) in es_by_name), None)
                o['_variant'] = True
            elif not s and e['name'] in ITEM_NAMES:
                o['name'] = ITEM_NAMES[e['name']]
            if s:
                o.setdefault('name', s['name'])
                body = strip_item_header(s['_body'])
                if body:
                    o['desc'] = body
            o.pop('_variant', None)
            if e.get('damage'):
                o['damage'] = tr_damage(e['damage'])
            if e.get('damage2h'):
                o['damage2h'] = tr_damage(e['damage2h'])
            if e.get('props'):
                o['props'] = tr_props(e['props'])
            if e.get('mastery'):
                o['mastery'] = MASTERY.get(norm(e['mastery']), e['mastery']).capitalize()
            if e.get('sub'):
                o['sub'] = SUBCATS.get(norm(e['sub']), e['sub'])
            if o:
                items[e['id']] = o
        out['items'] = items
        report(edition, 'objetos', en_items, m, es_eq + es_mg)
        # Estados
        es_rules = load_dir(src, 'reglas')
        by_slug = {r['_slug']: r for r in es_rules}
        conds = {}
        for c in en('conditions'):
            r = by_slug.get(CONDITIONS.get(c['id'], ''))
            if r:
                conds[c['id']] = {'name': r['name'], 'desc': r['_body']}
        out['conditions'] = conds
        # Clases
        es_cls = {norm(c['name']): c for c in load_dir(src, 'clases')}
        out['classes'] = {}
        for c in en('classes'):
            meta = es_cls.get(CLASSES.get(c['id'], ''))
            if meta:
                out['classes'][c['id']] = class_overlay(meta)
            else:
                out['classes'][c['id']] = {'name': CLASS_NAMES.get(c['id'], c['name']), 'features': {}}
        # Listas
        lists = en('lists')
        feats_es = {norm(f['name']): f for f in load_dir(src, 'dotes')}
        out['lists'] = {
            'species': [SPECIES.get(norm(x), x) for x in lists.get('species', [])],
            'subspecies': [subspecies_es(x) for x in lists.get('subspecies', [])],
            'backgrounds': [BACKGROUNDS.get(norm(x), x) for x in lists.get('backgrounds', [])],
            'languages': [LANGUAGES.get(norm(x), x) for x in lists.get('languages', [])],
            'feats': [],
        }
        for f in lists.get('feats', []):
            es_f = feats_es.get(FEATS.get(norm(f['name']), ''))
            out['lists']['feats'].append({'name': es_f['name'], 'desc': es_f['_body']} if es_f else f)
        # Reglas
        out['rules'] = rules_chapters(es_rules, edition)
        path = os.path.join(en_dir, 'es.json')
        json.dump(out, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
        print(f'{edition}: {path} ({os.path.getsize(path) // 1024} KB)')


def report(edition, what, en_list, matched, es_list):
    print(f'{edition} {what}: {len(matched)}/{len(en_list)} emparejados ({len(es_list)} en castellano)')
    if os.environ.get('VERBOSE'):
        by = {s['_slug']: s['name'] for s in es_list}
        by.update({'e:' + s['_slug']: s['name'] for s in es_list})
        by.update({'o:' + s['_slug']: s['name'] for s in es_list})
        for e in en_list:
            v = matched.get(e['id'])
            print(f"   {e['name']:40s} -> {by.get(v, '-') if v else '???'}")


if __name__ == '__main__':
    main()
