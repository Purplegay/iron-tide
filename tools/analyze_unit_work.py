"""Summarize unit-work probe output without mixing instrumented timings into FPS comparisons."""
import argparse
import json
from collections import defaultdict
from pathlib import Path


def analyze(run):
    inventory=json.loads((run/'unit-work-points.json').read_text('utf8'))
    points=inventory['points']
    data=json.loads((run/'unit-work.json').read_text('utf8'))
    functions={};loops={};phases={};types={};actors=[];hot={}
    for actor in data['actors']:
        row=types.setdefault(actor['type'],{'type':actor['type'],'actors':0,'updates':0,'timed_updates':0,'sampled_total_ms':0.0,'all_total_ms':0.0,'max_update_us':0,'estimated_total_ms':0.0,'states':{},'functions':{},'loops':{}})
        estimated=actor['total_us']/max(1,actor['timed_updates'])*actor['updates']/1000
        row['all_total_ms']+=actor.get('total_all_us',0)/1000
        row['max_update_us']=max(row['max_update_us'],actor.get('max_update_us',0))
        for key,values in actor.get('hot',{}).items():
            stat=hot.setdefault(key,points[int(key)]|{'calls':0,'total_ms':0.0,'max_ms':0.0})
            stat['calls']+=values[0];stat['total_ms']+=values[1]/1000;stat['max_ms']=max(stat['max_ms'],values[2]/1000)
        row['actors']+=1;row['updates']+=actor['updates'];row['timed_updates']+=actor['timed_updates'];row['sampled_total_ms']+=actor['total_us']/1000;row['estimated_total_ms']+=estimated
        actors.append({k:actor[k] for k in ['instance','type','side','updates','timed_updates','states']}|{'estimated_total_ms':estimated,'all_total_ms':actor.get('total_all_us',0)/1000,'max_update_us':actor.get('max_update_us',0),'max_update_frame':actor.get('max_update_frame',0)})
        for state,n in actor['states'].items():row['states'][state]=row['states'].get(state,0)+n
        for key,values in actor['functions'].items():
            point=points[int(key)]
            for target in [functions,row['functions']]:
                stat=target.setdefault(key,point|{'calls':0,'samples':0,'sampled_inclusive_us':0,'sampled_self_us':0,'estimated_inclusive_ms':0.0,'estimated_self_ms':0.0,'sampled_max_us':0})
                stat['calls']+=values[0];stat['samples']+=values[1];stat['sampled_inclusive_us']+=values[2];stat['sampled_self_us']+=values[3];stat['sampled_max_us']=max(stat['sampled_max_us'],values[4])
                if values[1]:
                    stat['estimated_inclusive_ms']+=values[2]/values[1]*values[0]/1000
                    stat['estimated_self_ms']+=values[3]/values[1]*values[0]/1000
        for key,values in actor['loops'].items():
            point=points[int(key)]
            for target in [loops,row['loops']]:
                stat=target.setdefault(key,point|{'entries':0,'iterations':0})
                stat['entries']+=values[0];stat['iterations']+=values[1]
        for name,values in actor['phases'].items():
            stat=phases.setdefault(name,{'phase':name,'calls':0,'samples':0,'sampled_total_us':0,'estimated_ms':0.0,'sampled_max_us':0})
            stat['calls']+=values[0];stat['samples']+=values[1];stat['sampled_total_us']+=values[2];stat['sampled_max_us']=max(stat['sampled_max_us'],values[3])
            if values[1]:stat['estimated_ms']+=values[2]/values[1]*values[0]/1000
    sort_cost=lambda rows:sorted(rows,key=lambda x:-x['estimated_self_ms'])
    sort_loops=lambda rows:sorted(rows,key=lambda x:-x['iterations'])
    for row in types.values():
        row['mean_update_us']=(row['all_total_ms']*1000/max(1,row['updates'])) if row['all_total_ms'] else row['sampled_total_ms']*1000/max(1,row['timed_updates'])
        row['functions']=sort_cost(row['functions'].values());row['loops']=sort_loops(row['loops'].values())
    result={'scope':data['scope'],'mode':inventory.get('mode','counts'),'hot_exact_inclusive':sorted(hot.values(),key=lambda x:-x['total_ms']),'traces':data.get('traces',[]),'coverage':{'functions':sum(p['kind']=='function' for p in points),'loops':sum(p['kind']=='loop' for p in points),'callbacks':sum(p['kind']=='callback' for p in points),'skipped':inventory['skipped']},'total_updates':sum(x['updates'] for x in types.values()),'total_timed_updates':sum(x['timed_updates'] for x in types.values()),'phases':sorted(phases.values(),key=lambda x:-x['estimated_ms']),'functions_by_self':sort_cost(functions.values()),'functions_by_calls':sorted(functions.values(),key=lambda x:-x['calls']),'loops_by_iterations':sort_loops(loops.values()),'types':sorted(types.values(),key=lambda x:-(x['all_total_ms'] or x['estimated_total_ms'])),'actors':sorted(actors,key=lambda x:-(x['all_total_ms'] or x['estimated_total_ms']))}
    (run/'unit-work-summary.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),'utf8')
    print('updates',result['total_updates'],'timed',result['total_timed_updates'])
    for category,columns in [('hot_exact_inclusive',['source','function','calls','total_ms','max_ms']),('types',['type','updates','mean_update_us','all_total_ms','max_update_us']),('phases',['phase','calls','estimated_ms']),('functions_by_self',['source','function','calls','samples','estimated_self_ms','estimated_inclusive_ms']),('loops_by_iterations',['source','function','line','entries','iterations','code'])]:
        print(category)
        for row in result[category][:20]:print(' | '.join(str(round(row[k],2) if isinstance(row[k],float) else row[k]) for k in columns))
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('run',type=Path)
    analyze(parser.parse_args().run)
