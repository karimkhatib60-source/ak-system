// Standard BOQ items with professional wording, grouped by trade. Picking
// one fills the description and unit; the quantity and rate are entered
// per project.

class BoqItem {
  const BoqItem(this.description, this.unit);

  final String description;
  final String unit;
}

class BoqTrade {
  const BoqTrade(this.name, this.items);

  final String name;
  final List<BoqItem> items;
}

const boqLibrary = <BoqTrade>[
  BoqTrade('Design services', [
    BoqItem(
      'Site visit, survey of existing conditions and measured drawings',
      'lump sum',
    ),
    BoqItem(
      'Concept design: space planning, massing and design options with '
          'presentation',
      'lump sum',
    ),
    BoqItem(
      'Schematic design: developed plans, sections, elevations and 3D views',
      'lump sum',
    ),
    BoqItem(
      'Design development: coordinated architectural drawings and material '
          'selections',
      'lump sum',
    ),
    BoqItem(
      'Permit drawings and submission file to the Order of Engineers and '
          'municipality',
      'lump sum',
    ),
    BoqItem(
      'Construction (execution) drawings, details and schedules',
      'lump sum',
    ),
    BoqItem(
      'Interior design package: layouts, ceilings, finishes, joinery',
      'm²',
    ),
    BoqItem('Photorealistic 3D renderings', 'image'),
    BoqItem('Bill of quantities and technical specifications', 'lump sum'),
    BoqItem(
      'Tender documents, bid analysis and contractor recommendation',
      'lump sum',
    ),
    BoqItem('Periodic site supervision visit with written report', 'visit'),
  ]),
  BoqTrade('Consultancy', [
    BoqItem(
      'Review of drawings and design documents with written comments',
      'lump sum',
    ),
    BoqItem(
      'Technical site inspection and condition assessment report',
      'visit',
    ),
    BoqItem(
      'Value engineering study with cost-saving recommendations',
      'lump sum',
    ),
    BoqItem('Feasibility study and area / programme analysis', 'lump sum'),
    BoqItem(
      'Coordination meeting with client, consultants or authorities',
      'meeting',
    ),
    BoqItem('Consultancy hours', 'hour'),
  ]),
  BoqTrade('Preliminaries', [
    BoqItem(
      'Mobilization, site setup, temporary facilities and site office',
      'lump sum',
    ),
    BoqItem(
      'Protection of existing finishes, lifts and common areas',
      'lump sum',
    ),
    BoqItem('Temporary electricity and water for construction', 'lump sum'),
    BoqItem(
      'Site cleaning during works and final cleaning at handover',
      'lump sum',
    ),
    BoqItem('Debris removal and disposal to an approved dump site', 'trip'),
    BoqItem('Scaffolding supply, erection and dismantling', 'm²'),
  ]),
  BoqTrade('Demolition', [
    BoqItem(
      'Demolition of existing block walls including removal of debris',
      'm²',
    ),
    BoqItem('Removal of existing floor tiles and screed down to slab', 'm²'),
    BoqItem('Removal of existing wall tiles and plaster', 'm²'),
    BoqItem('Removal of existing false ceilings', 'm²'),
    BoqItem('Removal of existing doors and windows with frames', 'no.'),
    BoqItem('Removal of existing sanitary ware and fittings', 'no.'),
    BoqItem('Concrete cutting / coring for openings and services', 'lin. m'),
  ]),
  BoqTrade('Earthworks', [
    BoqItem('Site clearance and removal of vegetation and top soil', 'm²'),
    BoqItem(
      'Excavation in all kinds of soil for foundations, including rock',
      'm³',
    ),
    BoqItem('Backfilling with approved material, compacted in layers', 'm³'),
    BoqItem('Anti-termite treatment of soil under slabs', 'm²'),
    BoqItem('Polyethylene sheet 1000 gauge under slab on grade', 'm²'),
  ]),
  BoqTrade('Concrete works', [
    BoqItem('Plain concrete blinding, 10 cm thick, 200 kg/m³', 'm³'),
    BoqItem(
      'Reinforced concrete for footings and tie beams, C30, incl. steel and formwork',
      'm³',
    ),
    BoqItem('Reinforced concrete for columns and shear walls, C30', 'm³'),
    BoqItem('Reinforced concrete for beams and slabs, C30', 'm³'),
    BoqItem('Hollow block (hourdi) slab, total thickness 30 cm', 'm²'),
    BoqItem('Reinforced concrete stairs including landings', 'm³'),
    BoqItem(
      'Reinforcement steel Grade 60, supplied, cut, bent and fixed',
      'ton',
    ),
  ]),
  BoqTrade('Masonry', [
    BoqItem('Concrete block wall, 20 cm thick, in cement mortar', 'm²'),
    BoqItem('Concrete block wall, 15 cm thick, in cement mortar', 'm²'),
    BoqItem('Concrete block wall, 10 cm thick, in cement mortar', 'm²'),
    BoqItem(
      'Reinforced concrete lintels and tie beams over openings',
      'lin. m',
    ),
    BoqItem(
      'Natural stone cladding for external walls, dressed, with backing concrete',
      'm²',
    ),
  ]),
  BoqTrade('Plastering', [
    BoqItem('Internal cement plaster, two coats, 2 cm, on walls', 'm²'),
    BoqItem('Internal cement plaster on ceilings', 'm²'),
    BoqItem(
      'External cement plaster, three coats, with waterproof additive',
      'm²',
    ),
    BoqItem('Corner beads and expansion profiles', 'lin. m'),
  ]),
  BoqTrade('Waterproofing and insulation', [
    BoqItem(
      'Bituminous membrane waterproofing, 4 mm, for roofs, with protection screed',
      'm²',
    ),
    BoqItem(
      'Cementitious waterproofing for wet areas, turned up 30 cm on walls',
      'm²',
    ),
    BoqItem('Thermal insulation boards, extruded polystyrene 5 cm', 'm²'),
    BoqItem('Lightweight concrete for roof slopes, average 10 cm', 'm²'),
  ]),
  BoqTrade('Tiling and flooring', [
    BoqItem('Cement screed 5 cm for floor finishes', 'm²'),
    BoqItem(
      'Porcelain floor tiles 60x60 cm, supply and installation, with grout',
      'm²',
    ),
    BoqItem(
      'Porcelain wall tiles for bathrooms and kitchen, full height',
      'm²',
    ),
    BoqItem('Porcelain skirting 10 cm', 'lin. m'),
    BoqItem('Engineered wood parquet flooring with underlay', 'm²'),
    BoqItem('Outdoor anti-slip tiles for balconies and terraces', 'm²'),
  ]),
  BoqTrade('Marble and stone', [
    BoqItem('Marble flooring 2 cm, polished, supply and installation', 'm²'),
    BoqItem('Marble stair treads and risers', 'lin. m'),
    BoqItem('Marble window sills and thresholds', 'lin. m'),
    BoqItem(
      'Kitchen countertop, quartz or granite, 2 cm with edge finish',
      'lin. m',
    ),
    BoqItem('Vanity countertop, marble, with undermount basin cut-out', 'no.'),
  ]),
  BoqTrade('Gypsum and ceilings', [
    BoqItem(
      'Gypsum board false ceiling on galvanized steel frame, painted',
      'm²',
    ),
    BoqItem('Moisture-resistant gypsum board ceiling for wet areas', 'm²'),
    BoqItem(
      'Gypsum board partition, double sided, with acoustic insulation',
      'm²',
    ),
    BoqItem('Gypsum cornice / light cove with concealed LED profile', 'lin. m'),
    BoqItem('Access panel 60x60 cm in ceiling', 'no.'),
  ]),
  BoqTrade('Painting', [
    BoqItem(
      'Internal walls: sealer, two coats putty, primer and two coats emulsion paint',
      'm²',
    ),
    BoqItem('Ceilings: putty, primer and two coats emulsion paint', 'm²'),
    BoqItem(
      'External walls: primer and two coats elastomeric exterior paint',
      'm²',
    ),
    BoqItem('Decorative / textured paint finish to feature walls', 'm²'),
    BoqItem(
      'Enamel paint on metal works, two coats over anti-rust primer',
      'm²',
    ),
  ]),
  BoqTrade('Carpentry and joinery', [
    BoqItem(
      'Internal door, solid core, veneer finish, with frame, architrave and ironmongery',
      'no.',
    ),
    BoqItem(
      'Main entrance security door, steel armoured with wood finish',
      'no.',
    ),
    BoqItem(
      'Kitchen cabinets, base and wall units, lacquer or HPL finish, with accessories',
      'lin. m',
    ),
    BoqItem('Built-in wardrobe, full height, with internal fittings', 'lin. m'),
    BoqItem('Bathroom vanity unit, water-resistant MDF', 'no.'),
    BoqItem('Wall cladding / TV unit in wood veneer', 'm²'),
  ]),
  BoqTrade('Aluminium and glazing', [
    BoqItem(
      'Aluminium sliding windows, thermal break, double glazed 6-12-6',
      'm²',
    ),
    BoqItem('Aluminium casement / tilt-and-turn windows, double glazed', 'm²'),
    BoqItem('Aluminium sliding doors to balconies, double glazed', 'm²'),
    BoqItem('Shower glass enclosure, 10 mm tempered, with fittings', 'no.'),
    BoqItem(
      'Glass balustrade, laminated tempered glass with stainless steel fixings',
      'lin. m',
    ),
  ]),
  BoqTrade('Metal works', [
    BoqItem('Steel balustrade / handrail, painted', 'lin. m'),
    BoqItem('Steel structure for canopy or pergola, painted', 'kg'),
    BoqItem('Steel gate, painted, with automation provision', 'm²'),
    BoqItem('Stainless steel handrail for stairs', 'lin. m'),
  ]),
  BoqTrade('Plumbing and sanitary', [
    BoqItem(
      'Water supply network (hot and cold), PPR pipes, per wet point',
      'point',
    ),
    BoqItem('Drainage network, uPVC pipes, per wet point', 'point'),
    BoqItem('Wall-hung WC with concealed cistern and flush plate', 'no.'),
    BoqItem('Washbasin with mixer and waste', 'no.'),
    BoqItem('Shower set: concealed mixer, head shower and hand shower', 'no.'),
    BoqItem('Kitchen sink, stainless steel, with mixer', 'no.'),
    BoqItem('Electric water heater 80 L, installed', 'no.'),
    BoqItem('Solar water heating system, complete', 'set'),
    BoqItem('Water storage tank with booster pump', 'set'),
  ]),
  BoqTrade('Electrical', [
    BoqItem('Lighting point including conduit, wiring and switch', 'point'),
    BoqItem('Power socket 13 A including conduit and wiring', 'point'),
    BoqItem('Dedicated power point for AC / kitchen appliance', 'point'),
    BoqItem('Main distribution board with breakers, complete', 'no.'),
    BoqItem('Data / TV outlet including cabling to rack', 'point'),
    BoqItem('LED downlights, supply and installation', 'no.'),
    BoqItem('LED strip lighting with driver', 'lin. m'),
    BoqItem('Earthing system complete', 'lump sum'),
    BoqItem('Generator / UPS changeover connection', 'lump sum'),
  ]),
  BoqTrade('HVAC', [
    BoqItem(
      'Split AC unit, inverter, 12,000 BTU, installed with piping',
      'no.',
    ),
    BoqItem(
      'Split AC unit, inverter, 18,000 BTU, installed with piping',
      'no.',
    ),
    BoqItem('Ducted concealed AC unit with ductwork and grilles', 'ton'),
    BoqItem('Exhaust fan for bathrooms and kitchen, with duct', 'no.'),
    BoqItem('Copper piping and drain line for AC, insulated', 'lin. m'),
  ]),
  BoqTrade('Landscape and external works', [
    BoqItem('Topsoil supply and spreading for planting areas', 'm³'),
    BoqItem('Natural grass / lawn installation', 'm²'),
    BoqItem('Trees and shrubs, supply and planting', 'no.'),
    BoqItem('Drip irrigation network with controller', 'm²'),
    BoqItem('External paving with interlocking pavers on sand bed', 'm²'),
    BoqItem('Boundary wall, reinforced concrete with stone cladding', 'lin. m'),
  ]),
];
