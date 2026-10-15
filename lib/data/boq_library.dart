// AK master BOQ library: standard items written to specification level,
// grouped by trade (the BOQ section) and by sub-group inside each trade.
// Picking an item fills its description, unit and section; only the
// quantity and rate are entered per project.

class BoqItem {
  const BoqItem(this.description, this.unit);

  final String description;
  final String unit;
}

class BoqGroup {
  const BoqGroup(this.name, this.items);

  final String name;
  final List<BoqItem> items;
}

class BoqTrade {
  const BoqTrade(this.code, this.name, this.groups);

  /// Two-digit trade number, as used in the BOQ.
  final String code;
  final String name;
  final List<BoqGroup> groups;

  Iterable<BoqItem> get items => groups.expand((g) => g.items);
}

/// All trade names in BOQ order, used as the section list.
List<String> get boqSections => [for (final t in boqLibrary) t.name];

const _ls = 'lump sum';
const _m2 = 'm²';
const _m3 = 'm³';
const _lm = 'lin. m';
const _no = 'no.';
const _pt = 'point';
const _set = 'set';
const _kg = 'kg';
const _ton = 'ton';
const _mo = 'month';

const boqLibrary = <BoqTrade>[
  BoqTrade('01', 'Design services', [
    BoqGroup('Survey and brief', [
      BoqItem(
        'Site visit, survey of existing conditions, photographic record and '
        'measured drawings of the existing building',
        _ls,
      ),
      BoqItem(
        'Topographic survey by licensed surveyor, with levels, boundaries '
        'and existing trees',
        _ls,
      ),
      BoqItem(
        'Client brief, space programme and area schedule, with zoning '
        'analysis and regulatory check (exploitation factors, setbacks)',
        _ls,
      ),
    ]),
    BoqGroup('Architecture', [
      BoqItem(
        'Concept design: site analysis, design approach, space planning, '
        'massing studies and two design options, with presentation',
        _ls,
      ),
      BoqItem(
        'Schematic design: developed plans, sections and elevations at '
        '1:100, with 3D massing views and outline material palette',
        _ls,
      ),
      BoqItem(
        'Design development: coordinated architectural drawings at 1:50, '
        'finishes schedule and outline specifications',
        _ls,
      ),
      BoqItem(
        'Permit drawings and complete submission file to the Order of '
        'Engineers and Architects and the municipality, follow-up until '
        'permit issue',
        _ls,
      ),
      BoqItem(
        'Construction (execution) drawings: setting-out, plans, sections, '
        'elevations, wall types, door and window schedules and details',
        _ls,
      ),
      BoqItem('Architectural design fee based on built-up area', _m2),
    ]),
    BoqGroup('Interior design', [
      BoqItem(
        'Interior concept: mood boards, layout options and material and '
        'colour palette',
        _ls,
      ),
      BoqItem(
        'Interior design package: furniture layouts, reflected ceiling '
        'plans, flooring patterns, wall elevations and finishes schedule',
        _m2,
      ),
      BoqItem(
        'Joinery and custom furniture design with shop-drawing level '
        'details',
        _ls,
      ),
      BoqItem(
        'Lighting design: lighting layout, fixture schedule and switching '
        'scenes',
        _ls,
      ),
      BoqItem(
        'Loose furniture, accessories and lighting selection with supplier '
        'schedule and budget',
        _ls,
      ),
      BoqItem('Photorealistic 3D rendering, interior or exterior', 'image'),
      BoqItem('Walk-through 3D animation', _ls),
    ]),
    BoqGroup('Engineering coordination', [
      BoqItem(
        'Structural design and calculation note, with structural drawings '
        '(by licensed structural engineer)',
        _ls,
      ),
      BoqItem(
        'Mechanical design: plumbing, drainage, HVAC and fire fighting '
        'drawings and specifications',
        _ls,
      ),
      BoqItem(
        'Electrical design: power, lighting, low-current and earthing '
        'drawings with load calculations',
        _ls,
      ),
      BoqItem(
        'Coordination of all disciplines and clash review of drawings',
        _ls,
      ),
    ]),
    BoqGroup('Tender documents', [
      BoqItem(
        'Detailed bill of quantities with quantity take-off from drawings',
        _ls,
      ),
      BoqItem('Technical specifications for all trades', _ls),
      BoqItem('Cost estimate of the works at design stage', _ls),
      BoqItem(
        'Tender documents, invitation of contractors, bid analysis and '
        'recommendation for award',
        _ls,
      ),
    ]),
  ]),
  BoqTrade('02', 'Consultancy and supervision', [
    BoqGroup('Consultancy', [
      BoqItem(
        'Review of drawings and design documents with written comments '
        'report',
        _ls,
      ),
      BoqItem(
        'Technical site inspection and building condition assessment '
            'report with photos and recommendations',
        'visit',
      ),
      BoqItem('Value engineering study with cost-saving alternatives', _ls),
      BoqItem(
        'Feasibility study: area analysis, development options and '
        'budget estimate',
        _ls,
      ),
      BoqItem('Review of contractor quotations and bill of quantities', _ls),
      BoqItem(
        'Coordination meeting with client, consultants or authorities, '
            'with minutes of meeting',
        'meeting',
      ),
      BoqItem('Consultancy services, hourly rate', 'hour'),
    ]),
    BoqGroup('Supervision and project management', [
      BoqItem(
        'Periodic site supervision visit with written site report',
        'visit',
      ),
      BoqItem('Full-time resident site engineer', _mo),
      BoqItem(
        'Project management: programme, cost control, monthly progress '
        'report and coordination of contractors and suppliers',
        _mo,
      ),
      BoqItem(
        'Checking and certifying contractor payment applications',
        'certificate',
      ),
      BoqItem('Review and approval of shop drawings and material samples', _ls),
      BoqItem(
        'Snag list, final inspection and handover with as-built review',
        _ls,
      ),
    ]),
  ]),
  BoqTrade('03', 'Preliminaries', [
    BoqGroup('Site setup', [
      BoqItem(
        'Mobilization of labour, plant and equipment to site, and '
        'demobilization on completion',
        _ls,
      ),
      BoqItem(
        'Site office, storage and workers facilities, maintained for the '
        'duration of the works',
        _ls,
      ),
      BoqItem('Temporary hoarding / site fence with gate, 2.4 m high', _lm),
      BoqItem('Project sign board as per design', _no),
      BoqItem(
        'Temporary electricity supply and distribution for construction',
        _ls,
      ),
      BoqItem('Temporary water supply for construction', _ls),
    ]),
    BoqGroup('Protection and safety', [
      BoqItem(
        'Protection of existing finishes, lifts, staircases and common '
        'areas throughout the works',
        _ls,
      ),
      BoqItem(
        'Health and safety measures: PPE, signage, first aid and fire '
        'extinguishers on site',
        _ls,
      ),
      BoqItem(
        'Scaffolding, supply, erection, maintenance and dismantling',
        _m2,
      ),
      BoqItem('Contractor all-risk and third-party insurance', _ls),
    ]),
    BoqGroup('General', [
      BoqItem('Setting out of the works by licensed surveyor', _ls),
      BoqItem(
        'Shop drawings, material submittals and samples for approval',
        _ls,
      ),
      BoqItem(
        'Daily cleaning of site and removal of debris to an approved dump',
        _ls,
      ),
      BoqItem('Debris removal by truck to an approved dump site', 'trip'),
      BoqItem('As-built drawings and operation manuals at handover', _ls),
    ]),
  ]),
  BoqTrade('04', 'Demolition and removal', [
    BoqGroup('Walls and structure', [
      BoqItem(
        'Demolition of existing block walls of all thicknesses, including '
        'plaster, finishes and removal of debris',
        _m2,
      ),
      BoqItem(
        'Demolition of reinforced concrete elements by saw cutting and '
        'breaking, including removal',
        _m3,
      ),
      BoqItem(
        'Concrete core drilling for services openings, diameter up to '
        '150 mm',
        _no,
      ),
      BoqItem('Saw cutting of concrete slabs or walls for new openings', _lm),
    ]),
    BoqGroup('Finishes', [
      BoqItem(
        'Removal of existing floor tiles or marble and screed down to '
        'structural slab',
        _m2,
      ),
      BoqItem('Removal of existing wall tiles and backing plaster', _m2),
      BoqItem('Scraping of existing paint to sound plaster', _m2),
      BoqItem(
        'Removal of existing false ceilings including suspension system',
        _m2,
      ),
      BoqItem(
        'Removal of existing parquet or carpet flooring including '
        'underlay and adhesive',
        _m2,
      ),
    ]),
    BoqGroup('Fixtures and services', [
      BoqItem('Removal of existing doors with frames and architraves', _no),
      BoqItem(
        'Removal of existing windows and frames, making good of openings',
        _no,
      ),
      BoqItem('Removal of existing kitchen cabinets and countertops', _lm),
      BoqItem(
        'Removal of existing sanitary ware and fittings, capping of pipes',
        _no,
      ),
      BoqItem(
        'Disconnection and removal of existing electrical and plumbing '
        'installations',
        _ls,
      ),
      BoqItem('Removal of existing AC units, piping and brackets', _no),
    ]),
  ]),
  BoqTrade('05', 'Earthworks', [
    BoqGroup('Excavation', [
      BoqItem(
        'Site clearance, removal of vegetation, top soil and debris',
        _m2,
      ),
      BoqItem(
        'Bulk excavation in all kinds of soil including rock, with '
        'disposal of surplus material',
        _m3,
      ),
      BoqItem(
        'Excavation for foundations and tie beams in all kinds of soil '
        'including rock',
        _m3,
      ),
      BoqItem('Shoring and dewatering of excavations as required', _ls),
    ]),
    BoqGroup('Filling and treatment', [
      BoqItem(
        'Backfilling with approved selected material, in 20 cm layers, '
        'compacted to 95% modified Proctor',
        _m3,
      ),
      BoqItem(
        'Base course (crushed aggregate) 20 cm thick under slab on grade, '
        'compacted',
        _m2,
      ),
      BoqItem('Anti-termite soil treatment under slabs and foundations', _m2),
      BoqItem(
        'Polyethylene sheet 1000 gauge vapour barrier under slab on grade',
        _m2,
      ),
    ]),
  ]),
  BoqTrade('06', 'Concrete works', [
    BoqGroup('Plain concrete', [
      BoqItem(
        'Plain concrete blinding 10 cm thick, 250 kg/m³ cement content, '
        'under foundations',
        _m3,
      ),
      BoqItem('Plain concrete for slopes, fillings and bases', _m3),
    ]),
    BoqGroup('Reinforced concrete', [
      BoqItem(
        'Reinforced concrete C30 for isolated and combined footings, '
        'including formwork',
        _m3,
      ),
      BoqItem(
        'Reinforced concrete C30 for raft foundation, including formwork',
        _m3,
      ),
      BoqItem('Reinforced concrete C30 for tie beams and grade beams', _m3),
      BoqItem(
        'Reinforced concrete C30 for retaining walls, including '
        'waterstops',
        _m3,
      ),
      BoqItem(
        'Reinforced concrete C35 for columns and shear walls, fair-faced '
        'formwork',
        _m3,
      ),
      BoqItem('Reinforced concrete C30 for beams and solid slabs', _m3),
      BoqItem(
        'Ribbed (hourdi) slab with hollow concrete blocks, total thickness '
        '30 cm, including ribs, topping and reinforcement',
        _m2,
      ),
      BoqItem(
        'Reinforced concrete slab on grade 15 cm thick, with mesh '
        'reinforcement and power-float finish',
        _m2,
      ),
      BoqItem('Reinforced concrete stairs including landings and nosings', _m3),
      BoqItem('Reinforced concrete parapets, upstands and cornices', _lm),
    ]),
    BoqGroup('Reinforcement and accessories', [
      BoqItem(
        'Deformed reinforcement steel Grade 60, supplied, cut, bent and '
        'fixed including tie wire and spacers',
        _ton,
      ),
      BoqItem('Welded steel mesh reinforcement', _m2),
      BoqItem(
        'Post-installed rebar with epoxy anchoring for new to existing '
        'concrete',
        _no,
      ),
      BoqItem('PVC waterstop at construction joints', _lm),
    ]),
  ]),
  BoqTrade('07', 'Masonry', [
    BoqGroup('Block walls', [
      BoqItem(
        'Hollow concrete block wall 20 cm thick, laid in 1:3 cement '
        'mortar, including tie beams and lintels',
        _m2,
      ),
      BoqItem(
        'Hollow concrete block wall 15 cm thick, laid in 1:3 cement mortar',
        _m2,
      ),
      BoqItem(
        'Hollow concrete block wall 10 cm thick, laid in 1:3 cement mortar',
        _m2,
      ),
      BoqItem(
        'Double block cavity wall (15 + 10 cm) with 5 cm insulation board',
        _m2,
      ),
      BoqItem(
        'Lightweight AAC block wall (Ytong or equal) 20 cm thick with '
        'thin-bed adhesive',
        _m2,
      ),
      BoqItem('Solid concrete block wall for shafts and fire separation', _m2),
    ]),
    BoqGroup('Accessories', [
      BoqItem(
        'Reinforced concrete lintels and stiffening beams over openings',
        _lm,
      ),
      BoqItem(
        'Closing of existing openings with block work and making good',
        _m2,
      ),
      BoqItem('Bonding of new walls to existing with steel dowels', _lm),
    ]),
  ]),
  BoqTrade('08', 'Stone works', [
    BoqGroup('Cladding', [
      BoqItem(
        'Natural Lebanese stone cladding to external walls, 5 cm thick, '
        'hand dressed (taltish / msamsam), with backing concrete',
        _m2,
      ),
      BoqItem(
        'Natural stone cladding 3 cm thick, sawn finish, fixed with '
        'stainless steel anchors',
        _m2,
      ),
      BoqItem('Stone cornice, window frames (ataba) and sills', _lm),
      BoqItem('Stone corner quoins', _lm),
      BoqItem('Pointing of stone joints with coloured mortar', _m2),
      BoqItem(
        'Cleaning and restoration of existing stone facade with '
        'water-repellent treatment',
        _m2,
      ),
    ]),
    BoqGroup('Stone walls', [
      BoqItem(
        'Natural stone retaining wall, dry or mortar-laid, with concrete '
        'backing',
        _m3,
      ),
      BoqItem('Stone coping to boundary and parapet walls', _lm),
    ]),
  ]),
  BoqTrade('09', 'Waterproofing and insulation', [
    BoqGroup('Roofs', [
      BoqItem(
        'Lightweight foamed concrete for roof slopes, average thickness '
        '10 cm',
        _m2,
      ),
      BoqItem(
        'Torch-applied bituminous membrane, two layers 4 mm, polyester '
        'reinforced, turned up 30 cm on parapets',
        _m2,
      ),
      BoqItem('Extruded polystyrene thermal insulation boards 5 cm thick', _m2),
      BoqItem(
        'Protection screed 5 cm with expansion joints over membrane',
        _m2,
      ),
      BoqItem(
        'Liquid-applied polyurethane waterproofing to roof with UV top coat',
        _m2,
      ),
    ]),
    BoqGroup('Wet areas and basements', [
      BoqItem(
        'Two-coat cementitious flexible waterproofing to bathrooms and '
        'kitchens, turned up 30 cm (full height in showers)',
        _m2,
      ),
      BoqItem(
        'Bituminous membrane tanking to basement walls and foundations '
        'with protection board',
        _m2,
      ),
      BoqItem(
        'Waterproofing of water tanks and planters with approved coating',
        _m2,
      ),
      BoqItem('Waterproofing of balconies and terraces', _m2),
    ]),
    BoqGroup('Insulation', [
      BoqItem(
        'Rock wool acoustic insulation 5 cm in partitions and ceilings',
        _m2,
      ),
      BoqItem(
        'Thermal insulation boards to external walls (inside cavity)',
        _m2,
      ),
    ]),
  ]),
  BoqTrade('10', 'Plastering', [
    BoqGroup('Internal', [
      BoqItem(
        'Internal cement plaster to walls, two coats total 2 cm thick, '
        'with corner beads, true and plumb',
        _m2,
      ),
      BoqItem('Internal cement plaster to ceilings', _m2),
      BoqItem('Gypsum plaster skim coat on walls for paint finish', _m2),
      BoqItem(
        'Fibre mesh at junctions of block and concrete before plaster',
        _lm,
      ),
    ]),
    BoqGroup('External', [
      BoqItem(
        'External cement plaster three coats (spatter, scratch, finish) '
        'with waterproof additive',
        _m2,
      ),
      BoqItem('Drip grooves and expansion profiles to external plaster', _lm),
    ]),
  ]),
  BoqTrade('11', 'Screeds and flooring', [
    BoqGroup('Screeds', [
      BoqItem(
        'Sand and cement screed average 5 cm thick, levelled to receive '
        'floor finishes',
        _m2,
      ),
      BoqItem('Self-levelling screed 5 mm for parquet and vinyl', _m2),
      BoqItem('Lightweight concrete filling under floors, average 10 cm', _m2),
    ]),
    BoqGroup('Tiles', [
      BoqItem(
        'Porcelain floor tiles 60 x 60 cm, rectified, first grade, laid '
        'with tile adhesive and epoxy grout, 2 mm joints',
        _m2,
      ),
      BoqItem(
        'Large-format porcelain floor tiles 120 x 120 cm or 60 x 120 cm, '
        'rectified, with levelling clip system',
        _m2,
      ),
      BoqItem('Porcelain skirting 10 cm high, matching floor tiles', _lm),
      BoqItem(
        'Anti-slip porcelain tiles R11 for balconies, terraces and wet '
        'areas',
        _m2,
      ),
      BoqItem('Terrazzo tiles 40 x 40 cm, ground and polished', _m2),
    ]),
    BoqGroup('Wood and resilient', [
      BoqItem(
        'Engineered wood parquet 15 mm (oak top layer) on acoustic '
        'underlay, with matching skirting',
        _m2,
      ),
      BoqItem('Laminate flooring AC4 8 mm on underlay', _m2),
      BoqItem('Luxury vinyl tiles (LVT) glued on self-levelling screed', _m2),
      BoqItem(
        'Epoxy floor coating 2 mm for parking, technical and service areas',
        _m2,
      ),
      BoqItem('Floor threshold / transition profile, aluminium or brass', _lm),
    ]),
  ]),
  BoqTrade('12', 'Wall finishes and cladding', [
    BoqGroup('Wall tiles', [
      BoqItem(
        'Porcelain wall tiles to bathrooms, full height, with tile '
        'adhesive and grout, including aluminium corner trims',
        _m2,
      ),
      BoqItem('Kitchen backsplash tiles between counter and wall units', _m2),
      BoqItem('Mosaic tiles glass or stone for feature walls and showers', _m2),
      BoqItem('Shower niche with tiled or stone finish', _no),
    ]),
    BoqGroup('Cladding', [
      BoqItem('Wood veneer wall cladding panels on concealed frame', _m2),
      BoqItem('Fluted wood / MDF wall panels, painted or veneered', _m2),
      BoqItem('Wallpaper, vinyl backed, supply and installation', _m2),
      BoqItem('Fabric or leather upholstered wall panels', _m2),
      BoqItem('Mirror cladding 6 mm on plywood backing', _m2),
      BoqItem(
        'Large-format porcelain slab wall cladding (sintered stone)',
        _m2,
      ),
    ]),
  ]),
  BoqTrade('13', 'Marble and granite', [
    BoqGroup('Floors and stairs', [
      BoqItem(
        'Marble flooring 2 cm thick, polished, laid on mortar bed, ground '
        'and polished after installation',
        _m2,
      ),
      BoqItem(
        'Marble stair treads 3 cm and risers 2 cm, with polished nosing '
        'and anti-slip grooves',
        _lm,
      ),
      BoqItem('Marble skirting 10 cm high', _lm),
      BoqItem('Marble door thresholds', _lm),
    ]),
    BoqGroup('Sills and tops', [
      BoqItem('Marble or granite window sills with drip groove', _lm),
      BoqItem(
        'Kitchen countertop in quartz or granite 2 cm, with edge profile '
        'and sink and hob cut-outs',
        _lm,
      ),
      BoqItem('Vanity countertop in marble with undermount basin cut-out', _no),
      BoqItem('Marble wall cladding to bathrooms and feature walls', _m2),
    ]),
  ]),
  BoqTrade('14', 'Gypsum board and ceilings', [
    BoqGroup('Ceilings', [
      BoqItem(
        'Gypsum board false ceiling 12.5 mm on galvanized steel '
        'suspension system, jointed, taped and ready for paint',
        _m2,
      ),
      BoqItem(
        'Moisture-resistant (green) gypsum board ceiling for bathrooms and '
        'kitchens',
        _m2,
      ),
      BoqItem('Gypsum board bulkheads and drops, any profile', _lm),
      BoqItem('Light cove / cornice with concealed LED profile', _lm),
      BoqItem('Shadow gap profile at ceiling perimeter', _lm),
      BoqItem(
        'Mineral fibre acoustic ceiling tiles 60 x 60 cm on exposed grid',
        _m2,
      ),
      BoqItem('Access panel 60 x 60 cm, push-to-open', _no),
      BoqItem('Curtain pocket in gypsum ceiling', _lm),
    ]),
    BoqGroup('Partitions', [
      BoqItem(
        'Gypsum board partition, double layer each side on 75 mm studs, '
        'with rock wool insulation',
        _m2,
      ),
      BoqItem('Gypsum board wall lining on furring channels', _m2),
      BoqItem('Gypsum board shaft wall, fire rated 1 hour', _m2),
    ]),
  ]),
  BoqTrade('15', 'Painting', [
    BoqGroup('Internal', [
      BoqItem(
        'Internal walls: sealer, two coats putty sanded smooth, primer and '
        'two coats washable emulsion paint, colour to approval',
        _m2,
      ),
      BoqItem('Ceilings: putty, primer and two coats emulsion paint', _m2),
      BoqItem(
        'Gypsum board ceilings and partitions: joint finishing, primer and '
        'two coats emulsion paint',
        _m2,
      ),
      BoqItem(
        'Moisture-resistant anti-fungal paint for bathrooms and kitchens',
        _m2,
      ),
    ]),
    BoqGroup('External', [
      BoqItem(
        'External walls: primer and two coats elastomeric exterior paint',
        _m2,
      ),
      BoqItem('Textured exterior coating (rolled or sprayed)', _m2),
      BoqItem('Water-repellent silicone treatment to stone or concrete', _m2),
    ]),
    BoqGroup('Special finishes', [
      BoqItem(
        'Decorative finish (microcement, stucco or limewash) to feature '
        'walls',
        _m2,
      ),
      BoqItem(
        'Enamel paint on metal works: anti-rust primer and two coats',
        _m2,
      ),
      BoqItem('Varnish or lacquer to timber surfaces', _m2),
      BoqItem('Intumescent fire-protective paint to steel', _m2),
    ]),
  ]),
  BoqTrade('16', 'Doors and carpentry', [
    BoqGroup('Doors', [
      BoqItem(
        'Internal door 90 x 220 cm, solid core, natural veneer or lacquer '
        'finish, with solid wood frame, architraves, hinges, magnetic '
        'lock and lever handle',
        _no,
      ),
      BoqItem(
        'Internal flush door, full height, with concealed hinges and '
        'concealed frame',
        _no,
      ),
      BoqItem('Sliding pocket door with soft-close track', _no),
      BoqItem(
        'Main entrance security door, steel armoured, multipoint lock, '
        'wood or HPL finish both sides',
        _no,
      ),
      BoqItem('Fire-rated door 60 min with closer and panic bar', _no),
      BoqItem('Bathroom door with privacy lock and ventilation grille', _no),
    ]),
    BoqGroup('Carpentry', [
      BoqItem('Wood skirting 8 cm, painted or veneered', _lm),
      BoqItem('Wooden handrail on stairs, solid oak', _lm),
      BoqItem('Wood ceiling slats on battens', _m2),
      BoqItem('Ironmongery set for door (supply only, as per schedule)', _set),
    ]),
  ]),
  BoqTrade('17', 'Joinery and fitted furniture', [
    BoqGroup('Kitchen', [
      BoqItem(
        'Kitchen base units 60 cm deep, moisture-resistant carcass, '
        'lacquer / HPL fronts, soft-close hinges and drawers',
        _lm,
      ),
      BoqItem('Kitchen wall units 35 cm deep, matching finish', _lm),
      BoqItem('Kitchen tall units (fridge, oven and pantry)', _lm),
      BoqItem('Kitchen island with storage, excluding countertop', _no),
      BoqItem(
        'Kitchen accessories: corner carousel, cutlery inserts, bins and '
        'LED under-cabinet lighting',
        _set,
      ),
    ]),
    BoqGroup('Wardrobes and units', [
      BoqItem(
        'Built-in wardrobe full height, hinged or sliding doors, with '
        'internal shelves, drawers, hanging rails and lighting',
        _lm,
      ),
      BoqItem('Walk-in closet joinery, open shelving and drawers', _lm),
      BoqItem('Bathroom vanity unit, water-resistant MDF, wall hung', _no),
      BoqItem('TV wall unit with storage and cable management', _no),
      BoqItem('Shoe cabinet / entrance unit', _no),
      BoqItem('Laundry room cabinets', _lm),
    ]),
  ]),
  BoqTrade('18', 'Aluminium and glazing', [
    BoqGroup('Windows and doors', [
      BoqItem(
        'Aluminium sliding windows, thermal break profiles, double glazed '
        '6-12-6 mm, with insect screen and powder-coated finish',
        _m2,
      ),
      BoqItem(
        'Aluminium casement / tilt-and-turn windows, thermal break, double '
        'glazed',
        _m2,
      ),
      BoqItem(
        'Aluminium lift-and-slide doors to balconies, double glazed',
        _m2,
      ),
      BoqItem('Aluminium fixed glazing, double glazed', _m2),
      BoqItem('Aluminium louvres for ventilation and service areas', _m2),
      BoqItem('Motorized aluminium rolling shutters', _m2),
    ]),
    BoqGroup('Glass', [
      BoqItem(
        'Shower glass enclosure 10 mm tempered, frameless, with stainless '
        'steel fittings',
        _no,
      ),
      BoqItem(
        'Glass balustrade, laminated tempered 8+8 mm, in aluminium base '
        'channel',
        _lm,
      ),
      BoqItem('Frameless glass partition 12 mm tempered with door', _m2),
      BoqItem('Glass canopy on stainless steel brackets', _m2),
      BoqItem('Curtain wall system with double glazed units', _m2),
    ]),
  ]),
  BoqTrade('19', 'Metal works', [
    BoqGroup('Steel', [
      BoqItem(
        'Structural steel for canopies, pergolas and mezzanines, '
        'fabricated, erected and painted',
        _kg,
      ),
      BoqItem('Steel staircase with steel or wood treads', _no),
      BoqItem('Steel balustrade / handrail, painted', _lm),
      BoqItem('Stainless steel handrail grade 316', _lm),
      BoqItem('Steel gate, painted, with provision for automation', _m2),
      BoqItem('Gate automation motor with remote controls', _set),
      BoqItem('Steel security grilles to windows', _m2),
      BoqItem('Steel cat ladder with safety cage', _lm),
    ]),
  ]),
  BoqTrade('20', 'Plumbing and drainage', [
    BoqGroup('Water supply', [
      BoqItem(
        'Hot and cold water supply network in PPR pipes PN20, insulated '
        'hot water lines, per sanitary point',
        _pt,
      ),
      BoqItem(
        'Main water supply line from tank to apartment, PPR, with valves',
        _lm,
      ),
      BoqItem('Water manifold with isolation valves per bathroom', _no),
      BoqItem(
        'Polyethylene water storage tank 2,000 L on roof, with float valve '
        'and connections',
        _no,
      ),
      BoqItem('Booster pump set with pressure vessel', _set),
      BoqItem('Water filtration / softening system', _set),
      BoqItem('Electric water heater 80 L, installed with safety valve', _no),
      BoqItem('Heat pump water heater 200 L', _no),
    ]),
    BoqGroup('Drainage', [
      BoqItem(
        'Soil and waste drainage network in uPVC pipes, per sanitary point',
        _pt,
      ),
      BoqItem('uPVC drainage stack 110 mm with ventilation', _lm),
      BoqItem('Floor drain with stainless steel grating', _no),
      BoqItem('Linear shower drain, stainless steel', _no),
      BoqItem('Rainwater down pipes uPVC 110 mm with roof outlets', _lm),
      BoqItem('Manhole, concrete, with cast iron cover', _no),
      BoqItem('Septic tank / connection to public sewer', _ls),
    ]),
    BoqGroup('Sanitary fixtures', [
      BoqItem(
        'Wall-hung WC with concealed cistern frame, soft-close seat and '
        'flush plate',
        _no,
      ),
      BoqItem('Floor-mounted WC close-coupled with seat', _no),
      BoqItem('Bidet shower (shattaf) with angle valve', _no),
      BoqItem(
        'Washbasin, counter-top or undermount, with mixer and waste',
        _no,
      ),
      BoqItem(
        'Concealed shower mixer with rain head shower and hand shower set',
        _set,
      ),
      BoqItem('Bathtub, acrylic, with mixer and waste', _no),
      BoqItem('Kitchen sink, stainless steel, with mixer and waste', _no),
      BoqItem(
        'Bathroom accessories set (towel bars, hooks, paper holder)',
        _set,
      ),
      BoqItem('Washing machine connection point with valve and drain', _pt),
    ]),
  ]),
  BoqTrade('21', 'Electrical works', [
    BoqGroup('Distribution', [
      BoqItem(
        'Main distribution board with MCBs, RCDs and surge protection, '
        'complete',
        _no,
      ),
      BoqItem('Sub-distribution board per floor or apartment', _no),
      BoqItem(
        'Main feeder cable from meter to distribution board, XLPE copper',
        _lm,
      ),
      BoqItem(
        'Changeover switch between grid (EDL) and generator subscription',
        _no,
      ),
      BoqItem('Earthing system with copper rod and test pit', _ls),
    ]),
    BoqGroup('Wiring points', [
      BoqItem(
        'Lighting point: PVC conduit, 1.5 mm² copper wiring and switch, '
        'complete',
        _pt,
      ),
      BoqItem(
        'Power socket 13 A: PVC conduit, 2.5 mm² copper wiring, complete',
        _pt,
      ),
      BoqItem(
        'Dedicated power point for AC, oven, water heater or washing '
        'machine, 4-6 mm² wiring',
        _pt,
      ),
      BoqItem('USB / USB-C combined power socket', _pt),
      BoqItem('Outdoor weatherproof power socket IP65', _pt),
      BoqItem('Wiring accessories upgrade (designer switch range)', _no),
    ]),
    BoqGroup('Lighting', [
      BoqItem('LED recessed downlight, 10 W, 3000 K, with driver', _no),
      BoqItem('LED strip lighting with aluminium profile and driver', _lm),
      BoqItem('LED magnetic track lighting system', _lm),
      BoqItem('Outdoor wall light IP65', _no),
      BoqItem('Garden bollard / spike light IP65', _no),
      BoqItem('Emergency light with battery backup', _no),
      BoqItem('Decorative pendant or chandelier installation', _no),
    ]),
    BoqGroup('Low current', [
      BoqItem('Data outlet Cat6 including cabling to network rack', _pt),
      BoqItem('TV outlet with coaxial cable to satellite / IPTV point', _pt),
      BoqItem('Network rack with patch panel and switch', _no),
      BoqItem('Wi-Fi access point, ceiling mounted', _no),
      BoqItem(
        'Video intercom system with outdoor panel and indoor monitor',
        _set,
      ),
      BoqItem('CCTV IP camera with NVR recording', _no),
      BoqItem('Alarm system with sensors and keypad', _set),
      BoqItem('Smart home control: lighting and curtains automation', _ls),
      BoqItem('Motorized curtain track with motor', _lm),
    ]),
  ]),
  BoqTrade('22', 'HVAC', [
    BoqGroup('Air conditioning', [
      BoqItem(
        'Wall-mounted split AC unit, inverter, 12,000 BTU, installed with '
        'copper piping, drain and bracket',
        _no,
      ),
      BoqItem('Wall-mounted split AC unit, inverter, 18,000 BTU', _no),
      BoqItem('Wall-mounted split AC unit, inverter, 24,000 BTU', _no),
      BoqItem(
        'Ducted concealed AC unit with ductwork, linear grilles and '
        'thermostat',
        _ton,
      ),
      BoqItem('VRF system, outdoor and indoor units, complete', _ton),
      BoqItem('Insulated copper refrigerant piping with drain line', _lm),
      BoqItem('Pre-piping for future AC units (concealed)', _pt),
    ]),
    BoqGroup('Ventilation and heating', [
      BoqItem('Exhaust fan for bathroom with duct to outside', _no),
      BoqItem('Kitchen hood exhaust duct to outside', _no),
      BoqItem('Fresh air unit with heat recovery', _no),
      BoqItem('Underfloor heating, hydronic, with manifold and controls', _m2),
      BoqItem('Central heating radiator with valves and piping', _no),
      BoqItem('Boiler, diesel or gas, with chimney and controls', _no),
      BoqItem('Fireplace, wood or bio-ethanol, installed', _no),
    ]),
  ]),
  BoqTrade('23', 'Fire fighting and safety', [
    BoqGroup('Systems', [
      BoqItem('Fire extinguisher CO2 / dry powder with cabinet', _no),
      BoqItem('Fire hose reel cabinet complete', _no),
      BoqItem('Sprinkler head with piping', _no),
      BoqItem('Smoke detector, addressable or stand-alone', _no),
      BoqItem(
        'Fire alarm control panel with manual call points and sirens',
        _set,
      ),
      BoqItem('Fire water tank and pump set', _set),
    ]),
  ]),
  BoqTrade('24', 'Solar and energy', [
    BoqGroup('Solar power', [
      BoqItem(
        'Solar PV panels, monocrystalline 550 W, with aluminium mounting '
            'structure on roof',
        'kWp',
      ),
      BoqItem('Hybrid inverter 5 kW / 8 kW with monitoring', _no),
      BoqItem('Lithium battery storage 5 kWh', _no),
      BoqItem(
        'DC and AC cabling, protections, combiner box and earthing for PV '
        'system',
        _ls,
      ),
      BoqItem('Steel structure for solar panels (elevated / pergola)', _kg),
      BoqItem('Solar water heating system with collectors and tank', _set),
    ]),
  ]),
  BoqTrade('25', 'Swimming pool', [
    BoqGroup('Pool', [
      BoqItem('Reinforced concrete swimming pool shell, waterproofed', _m3),
      BoqItem('Pool mosaic or porcelain finish with coping stone', _m2),
      BoqItem(
        'Pool filtration system: pump, sand filter, skimmers, inlets and '
        'main drain',
        _set,
      ),
      BoqItem('Pool underwater LED light', _no),
      BoqItem('Pool heat pump', _no),
      BoqItem('Balance tank and overflow channel with grating', _lm),
    ]),
  ]),
  BoqTrade('26', 'External works and landscape', [
    BoqGroup('Hardscape', [
      BoqItem(
        'Interlocking concrete pavers 8 cm on 5 cm sand bed and compacted '
        'base course',
        _m2,
      ),
      BoqItem('Natural stone paving on mortar bed', _m2),
      BoqItem('Concrete kerbstones', _lm),
      BoqItem('Exposed aggregate or stamped concrete paving', _m2),
      BoqItem('Wooden or WPC decking on aluminium joists', _m2),
      BoqItem('External steps in stone', _lm),
    ]),
    BoqGroup('Walls and fences', [
      BoqItem(
        'Boundary wall in reinforced concrete with stone cladding and '
        'coping',
        _lm,
      ),
      BoqItem('Steel fence panels on low wall', _lm),
    ]),
    BoqGroup('Softscape', [
      BoqItem('Agricultural topsoil supply and spreading', _m3),
      BoqItem('Natural grass (sod) installation with soil preparation', _m2),
      BoqItem('Artificial grass 35 mm on prepared base', _m2),
      BoqItem('Trees, supply and planting (olive, ficus or as specified)', _no),
      BoqItem('Shrubs and ground cover planting', _m2),
      BoqItem(
        'Drip and sprinkler irrigation network with automatic controller',
        _m2,
      ),
      BoqItem('Concrete or fibreglass planters', _no),
      BoqItem('Pergola in steel or timber', _m2),
    ]),
  ]),
  BoqTrade('27', 'Cleaning and handover', [
    BoqGroup('Handover', [
      BoqItem(
        'Final deep cleaning of all areas, glass, fixtures and floors '
        'before handover',
        _m2,
      ),
      BoqItem('Testing and commissioning of all systems', _ls),
      BoqItem('Snag list rectification', _ls),
      BoqItem('Maintenance during defects liability period (12 months)', _ls),
    ]),
  ]),
];
