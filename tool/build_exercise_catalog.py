"""Génère la bibliothèque d'exercices de l'app à partir de free-exercise-db.

Les noms français et la sélection sont écrits ci-dessous ; les muscles et le
matériel viennent de free-exercise-db (domaine public). Pour ajouter un
exercice : l'ajouter à CURATED (ou OWN s'il n'existe pas là-bas), puis :

  curl -sSLo /tmp/fedb.json https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json
  python3 tool/build_exercise_catalog.py /tmp/fedb.json assets/exercises/catalog.json

Ne jamais changer la clé d'un exercice existant : elle relie l'historique.
"""
import json
import sys

W, B, D = "weightReps", "bodyweightReps", "duration"

# (clé, id free-exercise-db ou None, nom français, type, matériel imposé ou None)
CURATED = [
    # Pectoraux
    ("bench-press-barbell", "Barbell_Bench_Press_-_Medium_Grip", "Développé couché (barre)", W, None),
    ("bench-press-dumbbell", "Dumbbell_Bench_Press", "Développé couché (haltères)", W, None),
    ("incline-bench-press-barbell", "Barbell_Incline_Bench_Press_-_Medium_Grip", "Développé incliné (barre)", W, None),
    ("incline-bench-press-dumbbell", "Incline_Dumbbell_Press", "Développé incliné (haltères)", W, None),
    ("decline-bench-press-barbell", "Decline_Barbell_Bench_Press", "Développé décliné (barre)", W, None),
    ("decline-bench-press-dumbbell", "Decline_Dumbbell_Bench_Press", "Développé décliné (haltères)", W, None),
    ("bench-press-smith", "Smith_Machine_Bench_Press", "Développé couché (Smith machine)", W, None),
    ("incline-bench-press-smith", "Smith_Machine_Incline_Bench_Press", "Développé incliné (Smith machine)", W, None),
    ("chest-press-machine", "Leverage_Chest_Press", "Presse à pectoraux (machine)", W, None),
    ("incline-chest-press-machine", "Leverage_Incline_Chest_Press", "Presse à pectoraux inclinée (machine)", W, None),
    ("dumbbell-fly", "Dumbbell_Flyes", "Écarté couché (haltères)", W, None),
    ("incline-dumbbell-fly", "Incline_Dumbbell_Flyes", "Écarté incliné (haltères)", W, None),
    ("pec-deck", "Butterfly", "Butterfly (pec deck)", W, None),
    ("cable-crossover", "Cable_Crossover", "Écarté à la poulie haute (vis-à-vis)", W, None),
    ("low-cable-crossover", "Low_Cable_Crossover", "Écarté à la poulie basse (vis-à-vis)", W, None),
    ("push-up", "Pushups", "Pompes", B, "bodyweight"),
    ("incline-push-up", "Incline_Push-Up", "Pompes inclinées (mains surélevées)", B, "bodyweight"),
    ("decline-push-up", "Decline_Push-Up", "Pompes déclinées (pieds surélevés)", B, "bodyweight"),
    ("wide-push-up", "Push-Up_Wide", "Pompes prise large", B, "bodyweight"),
    ("chest-dip", "Dips_-_Chest_Version", "Dips (pectoraux)", B, "bodyweight"),
    ("dumbbell-pullover", "Straight-Arm_Dumbbell_Pullover", "Pull-over (haltère)", W, None),
    # Épaules
    ("overhead-press-barbell", "Standing_Military_Press", "Développé militaire (barre)", W, None),
    ("seated-overhead-press-barbell", "Seated_Barbell_Military_Press", "Développé militaire assis (barre)", W, None),
    ("seated-shoulder-press-dumbbell", "Seated_Dumbbell_Press", "Développé épaules assis (haltères)", W, None),
    ("standing-shoulder-press-dumbbell", "Standing_Dumbbell_Press", "Développé épaules debout (haltères)", W, None),
    ("arnold-press", "Arnold_Dumbbell_Press", "Développé Arnold (haltères)", W, None),
    ("shoulder-press-machine", "Machine_Shoulder_Military_Press", "Développé épaules (machine)", W, None),
    ("shoulder-press-smith", "Smith_Machine_Overhead_Shoulder_Press", "Développé épaules (Smith machine)", W, None),
    ("push-press", "Push_Press", "Push press (barre)", W, None),
    ("lateral-raise-dumbbell", "Side_Lateral_Raise", "Élévations latérales (haltères)", W, None),
    ("lateral-raise-cable", "Standing_Low-Pulley_Deltoid_Raise", "Élévation latérale à la poulie basse", W, None),
    ("front-raise-dumbbell", "Front_Dumbbell_Raise", "Élévations frontales (haltères)", W, None),
    ("front-raise-plate", "Front_Plate_Raise", "Élévation frontale (disque)", W, "plate"),
    ("front-raise-cable", "Front_Cable_Raise", "Élévation frontale (poulie)", W, None),
    ("rear-delt-fly-dumbbell", "Seated_Bent-Over_Rear_Delt_Raise", "Oiseau (haltères)", W, None),
    ("reverse-pec-deck", "Reverse_Machine_Flyes", "Oiseau à la machine (pec deck inversé)", W, None),
    ("rear-delt-fly-cable", "Cable_Rear_Delt_Fly", "Oiseau à la poulie", W, None),
    ("face-pull", "Face_Pull", "Face pull (poulie)", W, None),
    ("upright-row-barbell", "Upright_Barbell_Row", "Rowing menton (barre)", W, None),
    ("upright-row-dumbbell", "Standing_Dumbbell_Upright_Row", "Rowing menton (haltères)", W, None),
    ("upright-row-cable", "Upright_Cable_Row", "Rowing menton (poulie)", W, None),
    ("band-pull-apart", "Band_Pull_Apart", "Écartés à l'élastique (band pull-apart)", B, None),
    ("external-rotation-cable", "External_Rotation_with_Cable", "Rotation externe (poulie)", W, None),
    ("external-rotation-dumbbell", "External_Rotation", "Rotation externe (haltère)", W, None),
    # Trapèzes
    ("shrug-barbell", "Barbell_Shrug", "Haussements d'épaules (barre)", W, None),
    ("shrug-dumbbell", "Dumbbell_Shrug", "Haussements d'épaules (haltères)", W, None),
    ("shrug-machine", "Leverage_Shrug", "Haussements d'épaules (machine)", W, None),
    # Dos
    ("pull-up", "Pullups", "Tractions (pronation)", B, "bodyweight"),
    ("chin-up", "Chin-Up", "Tractions supination (chin-up)", B, "bodyweight"),
    ("neutral-grip-pull-up", "V-Bar_Pullup", "Tractions prise neutre", B, "bodyweight"),
    ("muscle-up", "Muscle_Up", "Muscle-up", B, "bodyweight"),
    ("lat-pulldown", "Wide-Grip_Lat_Pulldown", "Tirage vertical prise large", W, None),
    ("close-grip-lat-pulldown", "Close-Grip_Front_Lat_Pulldown", "Tirage vertical prise serrée", W, None),
    ("underhand-lat-pulldown", "Underhand_Cable_Pulldowns", "Tirage vertical supination", W, None),
    ("v-bar-lat-pulldown", "V-Bar_Pulldown", "Tirage vertical prise neutre (triangle)", W, None),
    ("straight-arm-pulldown", "Straight-Arm_Pulldown", "Pull-down bras tendus (poulie)", W, None),
    ("seated-cable-row", "Seated_Cable_Rows", "Tirage horizontal assis (poulie)", W, None),
    ("one-arm-cable-row", "Seated_One-arm_Cable_Pulley_Rows", "Tirage horizontal unilatéral (poulie)", W, None),
    ("barbell-row", "Bent_Over_Barbell_Row", "Rowing barre (buste penché)", W, None),
    ("reverse-grip-barbell-row", "Reverse_Grip_Bent-Over_Rows", "Rowing barre supination (Yates)", W, None),
    ("one-arm-dumbbell-row", "One-Arm_Dumbbell_Row", "Rowing unilatéral (haltère)", W, None),
    ("dumbbell-row", "Bent_Over_Two-Dumbbell_Row", "Rowing buste penché (haltères)", W, None),
    ("incline-dumbbell-row", "Dumbbell_Incline_Row", "Rowing sur banc incliné (haltères)", W, None),
    ("t-bar-row", "T-Bar_Row_with_Handle", "Rowing T-bar", W, None),
    ("machine-row", "Leverage_Iso_Row", "Rowing (machine)", W, None),
    ("inverted-row", "Inverted_Row", "Rowing inversé (poids du corps)", B, "bodyweight"),
    ("deadlift", "Barbell_Deadlift", "Soulevé de terre", W, None),
    ("sumo-deadlift", "Sumo_Deadlift", "Soulevé de terre sumo", W, None),
    ("romanian-deadlift-barbell", "Romanian_Deadlift", "Soulevé de terre roumain (barre)", W, None),
    ("romanian-deadlift-dumbbell", "Stiff-Legged_Dumbbell_Deadlift", "Soulevé de terre roumain (haltères)", W, None),
    ("stiff-leg-deadlift", "Stiff-Legged_Barbell_Deadlift", "Soulevé de terre jambes tendues (barre)", W, None),
    ("trap-bar-deadlift", "Trap_Bar_Deadlift", "Soulevé de terre à la trap bar", W, "barbell"),
    ("rack-pull", "Rack_Pulls", "Rack pull (barre)", W, None),
    ("good-morning", "Good_Morning", "Good morning (barre)", W, None),
    ("back-extension", "Hyperextensions_Back_Extensions", "Extensions lombaires (banc à 45°)", B, "other"),
    ("superman", "Superman", "Superman", B, "bodyweight"),
    # Biceps
    ("barbell-curl", "Barbell_Curl", "Curl barre", W, None),
    ("ez-bar-curl", "EZ-Bar_Curl", "Curl barre EZ", W, None),
    ("dumbbell-curl", "Dumbbell_Bicep_Curl", "Curl haltères", W, None),
    ("alternate-dumbbell-curl", "Dumbbell_Alternate_Bicep_Curl", "Curl alterné (haltères)", W, None),
    ("hammer-curl", "Hammer_Curls", "Curl marteau (haltères)", W, None),
    ("incline-dumbbell-curl", "Incline_Dumbbell_Curl", "Curl incliné (haltères)", W, None),
    ("concentration-curl", "Concentration_Curls", "Curl concentré (haltère)", W, None),
    ("preacher-curl", "Preacher_Curl", "Curl au pupitre (barre)", W, None),
    ("preacher-curl-machine", "Machine_Preacher_Curls", "Curl au pupitre (machine)", W, None),
    ("biceps-curl-machine", "Machine_Bicep_Curl", "Curl biceps (machine)", W, None),
    ("cable-curl", "Standing_Biceps_Cable_Curl", "Curl à la poulie basse", W, None),
    ("rope-hammer-curl", "Cable_Hammer_Curls_-_Rope_Attachment", "Curl marteau à la corde (poulie)", W, None),
    ("reverse-curl", "Reverse_Barbell_Curl", "Curl inversé (barre)", W, None),
    # Triceps
    ("triceps-pushdown", "Triceps_Pushdown", "Extension triceps poulie haute (barre)", W, None),
    ("rope-pushdown", "Triceps_Pushdown_-_Rope_Attachment", "Extension triceps poulie haute (corde)", W, None),
    ("overhead-rope-extension", "Triceps_Overhead_Extension_with_Rope", "Extension triceps au-dessus de la tête (corde)", W, None),
    ("overhead-dumbbell-extension", "Standing_Dumbbell_Triceps_Extension", "Extension triceps au-dessus de la tête (haltère)", W, None),
    ("skull-crusher", "EZ-Bar_Skullcrusher", "Barre au front (barre EZ)", W, None),
    ("lying-dumbbell-extension", "Lying_Dumbbell_Tricep_Extension", "Extension triceps couché (haltères)", W, None),
    ("dumbbell-kickback", "Tricep_Dumbbell_Kickback", "Kickback triceps (haltère)", W, None),
    ("close-grip-bench-press", "Close-Grip_Barbell_Bench_Press", "Développé couché prise serrée (barre)", W, None),
    ("triceps-extension-machine", "Machine_Triceps_Extension", "Extension triceps (machine)", W, None),
    ("triceps-dip", "Dips_-_Triceps_Version", "Dips (triceps)", B, "bodyweight"),
    ("bench-dip", "Bench_Dips", "Dips entre deux bancs", B, "bodyweight"),
    ("dip-machine", "Dip_Machine", "Dips (machine)", W, None),
    ("diamond-push-up", "Push-Ups_-_Close_Triceps_Position", "Pompes diamant (prise serrée)", B, "bodyweight"),
    # Avant-bras
    ("wrist-curl", "Seated_Palm-Up_Barbell_Wrist_Curl", "Curl poignets (barre)", W, None),
    ("reverse-wrist-curl", "Seated_Palms-Down_Barbell_Wrist_Curl", "Curl poignets inversé (barre)", W, None),
    # Quadriceps
    ("back-squat", "Barbell_Squat", "Squat (barre)", W, None),
    ("front-squat", "Front_Squat_Clean_Grip", "Squat avant (front squat)", W, None),
    ("goblet-squat", "Goblet_Squat", "Goblet squat", W, None),
    ("bodyweight-squat", "Bodyweight_Squat", "Squat au poids du corps", B, "bodyweight"),
    ("smith-squat", "Smith_Machine_Squat", "Squat (Smith machine)", W, None),
    ("hack-squat", "Hack_Squat", "Hack squat (machine)", W, None),
    ("leg-press", "Leg_Press", "Presse à cuisses", W, None),
    ("leg-extension", "Leg_Extensions", "Leg extension (machine)", W, None),
    ("dumbbell-lunge", "Dumbbell_Lunges", "Fentes avant (haltères)", W, None),
    ("barbell-lunge", "Barbell_Lunge", "Fentes avant (barre)", W, None),
    ("walking-lunge", "Bodyweight_Walking_Lunge", "Fentes marchées", B, "bodyweight"),
    ("reverse-lunge-dumbbell", "Dumbbell_Rear_Lunge", "Fentes arrière (haltères)", W, None),
    ("bulgarian-split-squat", "Split_Squat_with_Dumbbells", "Squat bulgare (haltères)", W, None),
    ("split-squat", "Split_Squats", "Fentes statiques (split squat)", B, "bodyweight"),
    ("dumbbell-step-up", "Dumbbell_Step_Ups", "Montées sur banc (haltères)", W, None),
    ("jump-squat", "Freehand_Jump_Squat", "Squat sauté", B, "bodyweight"),
    ("box-jump", "Front_Box_Jump", "Sauts sur boîte (box jump)", B, "other"),
    # Ischio-jambiers
    ("lying-leg-curl", "Lying_Leg_Curls", "Leg curl allongé (machine)", W, None),
    ("seated-leg-curl", "Seated_Leg_Curl", "Leg curl assis (machine)", W, None),
    ("standing-leg-curl", "Standing_Leg_Curl", "Leg curl debout (machine)", W, None),
    ("nordic-curl", "Natural_Glute_Ham_Raise", "Nordic curl", B, "bodyweight"),
    ("kettlebell-swing", "One-Arm_Kettlebell_Swings", "Kettlebell swing", W, None),
    # Fessiers
    ("hip-thrust", "Barbell_Hip_Thrust", "Hip thrust (barre)", W, None),
    ("glute-bridge-barbell", "Barbell_Glute_Bridge", "Pont fessier (barre)", W, None),
    ("glute-bridge", "Butt_Lift_Bridge", "Pont fessier (poids du corps)", B, "bodyweight"),
    ("single-leg-glute-bridge", "Single_Leg_Glute_Bridge", "Pont fessier sur une jambe", B, "bodyweight"),
    ("cable-glute-kickback", "One-Legged_Cable_Kickback", "Kickback fessier (poulie)", W, None),
    ("glute-kickback", "Glute_Kickback", "Kickback fessier au sol", B, "bodyweight"),
    ("hip-abduction-machine", "Thigh_Abductor", "Abducteurs (machine)", W, None),
    ("hip-adduction-machine", "Thigh_Adductor", "Adducteurs (machine)", W, None),
    # Mollets
    ("standing-calf-raise-machine", "Standing_Calf_Raises", "Mollets debout (machine)", W, None),
    ("seated-calf-raise", "Seated_Calf_Raise", "Mollets assis (machine)", W, None),
    ("leg-press-calf-raise", "Calf_Press_On_The_Leg_Press_Machine", "Mollets à la presse", W, None),
    ("standing-calf-raise-dumbbell", "Standing_Dumbbell_Calf_Raise", "Mollets debout (haltères)", W, None),
    # Abdominaux
    ("crunch", "Crunches", "Crunch", B, "bodyweight"),
    ("cable-crunch", "Cable_Crunch", "Crunch à la poulie (à genoux)", W, None),
    ("crunch-machine", "Ab_Crunch_Machine", "Crunch (machine)", W, None),
    ("reverse-crunch", "Reverse_Crunch", "Crunch inversé", B, "bodyweight"),
    ("decline-crunch", "Decline_Crunch", "Crunch sur banc décliné", B, "bodyweight"),
    ("sit-up", "Sit-Up", "Sit-up (relevé de buste)", B, "bodyweight"),
    ("hanging-leg-raise", "Hanging_Leg_Raise", "Relevé de jambes suspendu", B, "bodyweight"),
    ("captains-chair-knee-raise", "Knee_Hip_Raise_On_Parallel_Bars", "Relevé de genoux (chaise romaine)", B, "other"),
    ("lying-leg-raise", "Flat_Bench_Lying_Leg_Raise", "Relevé de jambes allongé", B, "bodyweight"),
    ("plank", "Plank", "Gainage (planche)", D, "bodyweight"),
    ("side-plank", "Side_Bridge", "Gainage latéral", D, "bodyweight"),
    ("russian-twist", "Russian_Twist", "Russian twist", B, "bodyweight"),
    ("ab-wheel", "Ab_Roller", "Roue abdominale", B, "other"),
    ("cable-woodchop", "Standing_Cable_Wood_Chop", "Bûcheron à la poulie (woodchop)", W, None),
    ("pallof-press", "Pallof_Press", "Pallof press (poulie)", W, None),
    ("dumbbell-side-bend", "Dumbbell_Side_Bend", "Flexion latérale (haltère)", W, None),
    ("dead-bug", "Dead_Bug", "Dead bug", B, "bodyweight"),
    ("mountain-climber", "Mountain_Climbers", "Mountain climbers", D, "bodyweight"),
    # Haltérophilie
    ("power-clean", "Power_Clean", "Épaulé (power clean)", W, None),
    ("clean-and-jerk", "Clean_and_Jerk", "Épaulé-jeté", W, None),
    ("snatch", "Snatch", "Arraché", W, None),
]

# Exercices absents de free-exercise-db : muscles renseignés à la main.
OWN = [
    ("pistol-squat", "Pistol squat", B, "quadriceps", ["glutes", "hamstrings"], "bodyweight"),
    ("wall-sit", "Chaise contre le mur", D, "quadriceps", ["glutes"], "bodyweight"),
    ("hollow-hold", "Hollow hold (gainage creux)", D, "abdominals", [], "bodyweight"),
    ("burpee", "Burpees", B, "quadriceps", ["chest", "shoulders", "triceps", "abdominals", "glutes"], "bodyweight"),
]

MUSCLES = {
    "abdominals": "abdominals", "abductors": "abductors", "adductors": "adductors",
    "biceps": "biceps", "calves": "calves", "chest": "chest", "forearms": "forearms",
    "glutes": "glutes", "hamstrings": "hamstrings", "lats": "lats",
    "lower back": "lowerBack", "middle back": "middleBack", "neck": "neck",
    "quadriceps": "quadriceps", "shoulders": "shoulders", "traps": "traps",
    "triceps": "triceps",
}

EQUIPMENT = {
    "barbell": "barbell", "e-z curl bar": "ezBar", "dumbbell": "dumbbell",
    "kettlebells": "kettlebell", "machine": "machine", "cable": "cable",
    "bands": "band", "body only": "bodyweight", None: "bodyweight",
}


def main(source_path, out_path):
    source = {x["id"]: x for x in json.load(open(source_path))}
    exercises = []
    for key, src, name, kind, equipment in CURATED:
        x = source[src]
        primary = MUSCLES[x["primaryMuscles"][0]]
        secondary = [MUSCLES[m] for m in x["secondaryMuscles"]]
        secondary = [m for m in dict.fromkeys(secondary) if m != primary]
        exercises.append({
            "key": key,
            "name": name,
            "type": kind,
            "primaryMuscle": primary,
            "secondaryMuscles": secondary,
            "equipment": equipment or EQUIPMENT[x["equipment"]],
            "source": src,
        })
    for key, name, kind, primary, secondary, equipment in OWN:
        exercises.append({
            "key": key,
            "name": name,
            "type": kind,
            "primaryMuscle": primary,
            "secondaryMuscles": secondary,
            "equipment": equipment,
            "source": None,
        })

    keys = [e["key"] for e in exercises]
    names = [e["name"] for e in exercises]
    assert len(keys) == len(set(keys)), "clé en double"
    assert len(names) == len(set(names)), "nom en double"

    catalog = {
        "about": (
            "Bibliothèque d'exercices fournie avec OpenSport. Noms français : "
            "OpenSport (GPL-3.0). Muscles et matériel repris de free-exercise-db "
            "(https://github.com/yuhonas/free-exercise-db, domaine public, "
            "Unlicense) ; « source » donne l'identifiant d'origine. Ne jamais "
            "changer la clé d'un exercice : elle relie l'historique."
        ),
        "exercises": exercises,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(len(exercises), "exercices")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
